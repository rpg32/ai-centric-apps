---
name: rag-engineering
description: Design and implement retrieval-augmented generation pipelines including chunking strategies, embedding models, vector databases, retrieval algorithms, and context window management.
user-invocable: false
---

# RAG Pipeline Engineering

## Purpose

Enable Claude to design, build, and optimize retrieval-augmented generation (RAG) pipelines that provide agents with accurate, relevant domain knowledge from external sources. Covers the full pipeline: document ingestion, chunking, embedding, storage, retrieval, re-ranking, and context injection.

## Key Rules

1. **Chunk Size Range**: 256-1024 tokens per chunk. Under 256 loses context; over 1024 dilutes relevance. Default starting point: 512 tokens with 64-token overlap. Adjust based on evaluation results.

2. **Embedding Model Selection**: Use `all-MiniLM-L6-v2` (384 dimensions) for prototyping and small deployments (<100K documents). Use `text-embedding-3-small` (1536 dimensions) from OpenAI for production with >100K documents. Use `text-embedding-3-large` (3072 dimensions) only when retrieval quality is the bottleneck.

3. **Retrieval Top-K**: Retrieve 5-10 chunks per query. Under 5 risks missing relevant content. Over 10 introduces noise and wastes context tokens. Start with k=5, increase only if evaluation shows retrieval recall <80%.

4. **Context Token Cap**: RAG results injected into the agent prompt must not exceed 4,000 tokens (simple agents) or 16,000 tokens (complex agents). If k=5 chunks at 512 tokens each = 2,560 tokens (within budget). If exceeding budget, re-rank and truncate to top 3.

5. **Document Freshness Tracking**: Every document in the vector store must have a `last_updated` metadata field. Documents older than 90 days should be flagged for review. Documents older than 180 days should trigger an update warning.

6. **Hybrid Search Over Pure Vector**: Use hybrid search (vector similarity + keyword matching) when the domain has specific terminology, product names, or codes that embedding models may not capture semantically. ChromaDB supports `where` metadata filters for hybrid approaches.

7. **Source Attribution Is Mandatory**: Every RAG-augmented agent response must include source citations. The retrieval pipeline must return document_id, chunk_id, and relevance_score alongside chunk content. Without attribution, users cannot verify accuracy.

## Decision Framework

### Choosing a Chunking Strategy

```
What type of documents are being ingested?
|
+-- Structured documents (markdown, HTML, code)
|   --> Semantic chunking: split on section headers, function boundaries
|       Tool: langchain RecursiveCharacterTextSplitter with language-aware separators
|       Separators: ["\n## ", "\n### ", "\n\n", "\n", " "]
|
+-- Long-form prose (books, reports, articles)
|   --> Recursive character splitting with overlap
|       Chunk size: 512 tokens, overlap: 64 tokens
|       Tool: langchain RecursiveCharacterTextSplitter
|
+-- Technical documentation (API docs, specs)
|   --> Section-aware chunking: preserve complete sections
|       Split on: section headers, keeping header with content
|       Maximum chunk: 1024 tokens (sections can be longer)
|       Tool: langchain MarkdownHeaderTextSplitter
|
+-- Code files
|   --> Function/class-level chunking
|       Split on: function definitions, class definitions
|       Include: docstrings, type hints, import context
|       Tool: langchain Language.PYTHON/JS text splitter
|
+-- Mixed content (docs with embedded code, images, tables)
    --> Multi-pass chunking: separate text, code, and table chunks
        Tag each chunk with content_type metadata
        Different embedding may be needed for code vs text
```

### Choosing a Vector Database

```
What are the deployment constraints?
|
+-- Prototyping or <50K documents
|   --> ChromaDB (embedded, no server needed)
|       Install: pip install chromadb
|       Storage: local SQLite + parquet files
|       Pros: zero config, fast setup
|       Cons: not horizontally scalable
|
+-- Production with existing PostgreSQL
|   --> pgvector (PostgreSQL extension)
|       Install: CREATE EXTENSION vector;
|       Pros: single database for app + vectors, SQL queries
|       Cons: requires PostgreSQL, manual index tuning
|
+-- Production, managed, >1M documents
|   --> Pinecone (cloud-managed)
|       Pros: auto-scaling, managed infrastructure, fast
|       Cons: vendor lock-in, per-query pricing
|
+-- Production, self-hosted, >1M documents
    --> Weaviate (open-source)
        Pros: hybrid search built-in, modular, GraphQL API
        Cons: operational complexity, resource-heavy
```

### Retrieval Quality Troubleshooting

```
RAG results are not relevant?
|
+-- Chunks retrieved but wrong topic
|   --> Embedding model mismatch or chunk too large
|       Fix: try smaller chunk size (256 tokens)
|       Fix: try different embedding model
|       Fix: add metadata filtering (topic, date, source)
|
+-- Correct topic but missing specific answer
|   --> Chunk boundaries split relevant content
|       Fix: increase overlap to 128 tokens
|       Fix: use semantic chunking instead of fixed-size
|       Fix: increase top-k from 5 to 8
|
+-- Too many irrelevant results mixed in
|   --> No re-ranking, or k too high
|       Fix: add re-ranking step (cross-encoder model)
|       Fix: reduce k from 10 to 5
|       Fix: add metadata filters to narrow search scope
|
+-- Domain-specific terms not matched
    --> Embedding model does not encode domain vocabulary
        Fix: use hybrid search (vector + keyword BM25)
        Fix: add synonyms to query expansion
        Fix: fine-tune embedding model on domain data (advanced)
```

## Procedures

### Procedure 1: Build a ChromaDB RAG Pipeline

1. **Install dependencies**:
   ```bash
   pip install chromadb sentence-transformers langchain-text-splitters
   ```

2. **Initialize ChromaDB**:
   ```python
   import chromadb

   client = chromadb.PersistentClient(path="./chroma_data")
   collection = client.get_or_create_collection(
       name="project_docs",
       metadata={"hnsw:space": "cosine"}  # cosine similarity
   )
   ```

3. **Chunk documents**:
   ```python
   from langchain_text_splitters import RecursiveCharacterTextSplitter

   splitter = RecursiveCharacterTextSplitter(
       chunk_size=512,
       chunk_overlap=64,
       separators=["\n## ", "\n### ", "\n\n", "\n", " "]
   )

   chunks = splitter.split_text(document_text)
   ```

4. **Add chunks to collection**:
   ```python
   collection.add(
       documents=chunks,
       ids=[f"doc_{doc_id}_chunk_{i}" for i in range(len(chunks))],
       metadatas=[{
           "source": filename,
           "chunk_index": i,
           "last_updated": "2026-02-20",
           "content_type": "text"
       } for i in range(len(chunks))]
   )
   ```

5. **Query the collection**:
   ```python
   results = collection.query(
       query_texts=["user query here"],
       n_results=5,
       include=["documents", "metadatas", "distances"]
   )

   # Format for agent context injection
   context_chunks = []
   for doc, meta, dist in zip(
       results["documents"][0],
       results["metadatas"][0],
       results["distances"][0]
   ):
       context_chunks.append({
           "content": doc,
           "source": meta["source"],
           "relevance_score": 1 - dist,  # convert distance to similarity
           "chunk_id": meta.get("chunk_index")
       })
   ```

6. **Inject into agent prompt**:
   ```python
   context_text = "\n\n".join([
       f"[Source: {c['source']}, Relevance: {c['relevance_score']:.2f}]\n{c['content']}"
       for c in context_chunks
   ])

   prompt = f"""<context>
   {context_text}
   </context>

   Based on the above context, answer the following question.
   Cite sources using [Source: filename] format.
   If the context does not contain the answer, say so explicitly.

   Question: {user_query}"""
   ```

### Procedure 2: Evaluate RAG Quality

1. **Create an evaluation dataset** with 20+ question-answer pairs:
   ```json
   [
     {
       "question": "What is the maximum voltage rating for component X?",
       "expected_answer": "50V",
       "source_document": "component_datasheet.pdf",
       "difficulty": "simple"
     }
   ]
   ```

2. **Measure retrieval metrics**:
   - **Recall@K**: What fraction of relevant chunks appear in top-K results? Target: >80%
   - **Precision@K**: What fraction of top-K results are actually relevant? Target: >60%
   - **MRR (Mean Reciprocal Rank)**: How high is the most relevant chunk ranked? Target: >0.7

3. **Measure answer quality**:
   - **Correctness**: Does the agent answer match the expected answer? Target: >85%
   - **Faithfulness**: Is the answer supported by the retrieved chunks (no hallucination)? Target: >95%
   - **Relevance**: Is the answer relevant to the question? Target: >90%

4. **Run evaluation using promptfoo**:
   ```yaml
   # promptfooconfig.yaml
   providers:
     - id: anthropic:messages:claude-sonnet-4-20250514
   tests:
     - vars:
         question: "What is the maximum voltage rating for component X?"
       assert:
         - type: contains
           value: "50V"
         - type: llm-rubric
           value: "Answer is factually correct and cites a source document"
   ```

### Procedure 3: Optimize Retrieval Quality

1. **Baseline measurement**: Run evaluation dataset and record metrics.

2. **Tuning knobs** (adjust one at a time, measure after each change):

   | Knob | Range | Effect | Measure After |
   |------|-------|--------|---------------|
   | Chunk size | 256-1024 tokens | Smaller = more precise, larger = more context | Recall@5, Precision@5 |
   | Overlap | 0-128 tokens | More overlap = fewer split answers | Recall@5 |
   | Top-K | 3-10 | Higher = more recall, lower = less noise | Recall@K, Precision@K |
   | Embedding model | MiniLM, ada-002, text-embedding-3 | Better model = better semantic matching | MRR, Recall@5 |
   | Metadata filters | None, topic, date, source | Narrower search = higher precision | Precision@5 |

3. **Iteration cycle**: Adjust knob -> run eval -> compare to baseline -> keep if improved, revert if not.

## Reference Tables

### Embedding Model Comparison

| Model | Dimensions | Speed | Quality (MTEB) | Cost | Best For |
|-------|-----------|-------|----------------|------|----------|
| all-MiniLM-L6-v2 | 384 | Fast (local) | Good (63.0) | Free | Prototyping, <100K docs |
| text-embedding-3-small | 1536 | Fast (API) | Better (62.3) | $0.02/1M tokens | Production, cost-sensitive |
| text-embedding-3-large | 3072 | Medium (API) | Best (64.6) | $0.13/1M tokens | High-accuracy requirements |
| voyage-3 | 1024 | Medium (API) | Best (67.2) | $0.06/1M tokens | Code + text mixed content |
| nomic-embed-text | 768 | Fast (local) | Good (62.4) | Free | Local/privacy-sensitive |

### Chunking Strategy Quick Reference

| Document Type | Strategy | Chunk Size | Overlap | Separators |
|--------------|----------|-----------|---------|------------|
| Markdown docs | Recursive + headers | 512 | 64 | `\n## `, `\n### `, `\n\n` |
| Plain text | Recursive character | 512 | 64 | `\n\n`, `\n`, `. `, ` ` |
| Python code | Language-aware | 1024 | 128 | Function/class boundaries |
| API documentation | Section-based | 768 | 0 | Section headers |
| PDF reports | Page-aware + recursive | 512 | 64 | Page breaks, `\n\n` |

### ChromaDB Distance Metrics

| Metric | Formula | Best For | Config Key |
|--------|---------|----------|------------|
| Cosine | 1 - cos(a,b) | General text similarity | `"hnsw:space": "cosine"` |
| L2 (Euclidean) | sqrt(sum((a-b)^2)) | Normalized embeddings | `"hnsw:space": "l2"` |
| Inner Product | -sum(a*b) | Pre-normalized vectors | `"hnsw:space": "ip"` |

Default: cosine. Use cosine unless you have a specific reason for another metric.

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| RAG Poisoning | Agent gives confidently wrong answers, cites outdated sources | Vector store contains stale or contradictory documents | Add `last_updated` metadata. Implement document expiration (>90 days = review, >180 days = warn). Build contradiction detection. |
| Chunk Boundary Split | Correct answer exists in the corpus but is split across two chunks, neither chunk alone has the complete answer | Fixed-size chunking splits mid-sentence or mid-paragraph | Increase overlap to 128 tokens. Switch to semantic chunking that respects paragraph boundaries. |
| Embedding Mismatch | Queries about specific terms (product names, codes) return semantically similar but wrong results | Embedding model maps different domain terms to similar vectors | Use hybrid search (vector + keyword). Add metadata filters for domain category. Consider domain-specific embedding model. |
| Context Token Overflow | LLM API returns token limit error, or agent ignores RAG context | Too many chunks retrieved, each too large | Reduce top-k to 5. Reduce chunk size to 512. Add re-ranking to filter low-relevance chunks before injection. Cap total RAG tokens at 4,000. |
| Empty Retrieval | Agent says "I don't have information about this" when the information exists in the corpus | Query does not match embedding space of stored documents | Try query expansion (add synonyms). Check if document was ingested correctly. Verify embedding model is the same for ingestion and query. |
| Duplicate Chunks | Same information appears multiple times in results, wasting context budget | Overlapping documents ingested, or same document re-ingested | De-duplicate during ingestion (hash-based). Add unique document IDs. Use `collection.get()` to check before adding. |

## Examples

### Example 1: Building a RAG Pipeline for a Q&A Application

**Scenario**: Technical documentation Q&A agent for a software product. 500 markdown files, ~2MB total.

**Step 1 - Chunking decision**: Markdown docs -> recursive + header-aware splitting, 512 tokens, 64 overlap.

**Step 2 - Embedding decision**: <100K docs -> `all-MiniLM-L6-v2` (free, local, adequate quality).

**Step 3 - Vector DB decision**: Prototyping phase -> ChromaDB (embedded, zero config).

**Step 4 - Retrieval config**: k=5, cosine similarity, no re-ranking (add later if precision <60%).

**Step 5 - Evaluation**:
- Created 25 Q&A pairs from the documentation
- Recall@5: 84% (target: >80%) -- PASS
- Precision@5: 68% (target: >60%) -- PASS
- Answer correctness: 88% (target: >85%) -- PASS

**Step 6 - Context injection token budget**:
- 5 chunks x 512 tokens = 2,560 tokens for RAG context
- System prompt: 1,500 tokens
- Conversation history: 2,000 tokens
- Total: 6,060 tokens -- well within claude-sonnet's 200K window

### Example 2: Optimizing Retrieval for Domain-Specific Terms

**Problem**: Agent cannot find information about "MOSFET gate drive circuits" because the embedding model maps "gate" to general concepts (gates, gateways) rather than electronics.

**Fix Applied**:
1. Added hybrid search with keyword matching for electronics terms
2. Added metadata filter: `{"domain": "electronics"}`
3. Expanded query: "MOSFET gate drive circuits" -> also search for "FET driver", "gate driver IC"

**Result**: Recall@5 improved from 52% to 87% for electronics-specific queries.
