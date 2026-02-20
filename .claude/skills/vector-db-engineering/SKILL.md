---
name: vector-db-engineering
description: Design, deploy, and optimize vector databases for RAG pipelines and semantic search, covering ChromaDB, pgvector, index selection, embedding tradeoffs, and hybrid search strategies.
user-invocable: false
---

# Vector Database Engineering

## Purpose

Enable Claude to select, configure, and optimize vector databases for RAG pipelines and semantic search within AI-centric applications. Covers ChromaDB (primary for prototyping), pgvector (production with PostgreSQL), index tuning, and hybrid search implementation.

## Key Rules

1. **ChromaDB Is the Default Starting Point**: For all new projects and prototyping, use ChromaDB. Zero configuration, embedded mode, persistent storage via SQLite. Switch to pgvector or Pinecone only when ChromaDB limitations are reached (>500K documents, need for SQL joins with vector search, or horizontal scaling).

2. **Same Embedding Model for Write and Read**: The embedding model used during ingestion MUST be the same model used during query. Mixing models produces meaningless similarity scores. Store the model name in collection metadata: `metadata={"embedding_model": "all-MiniLM-L6-v2"}`.

3. **Index Type Selection**: Use HNSW (Hierarchical Navigable Small Worlds) for most cases -- it is the default in ChromaDB and pgvector. HNSW provides ~95% recall with sub-100ms query times for collections under 1M documents. Switch to IVF only for >10M documents where memory is constrained.

4. **Metadata on Every Document**: Every ingested document must have metadata: `source` (filename/URL), `last_updated` (ISO date), `content_type` (text/code/table), and `user_id` (for multi-user scoping). Metadata enables filtering without re-embedding.

5. **Collection Naming Convention**: Use lowercase, hyphen-separated names: `project-docs`, `api-reference`, `user-uploads-{user_id}`. One collection per logical document set. Do not mix different content types in one collection unless they share the same embedding space.

6. **Batch Operations for Ingestion**: Add documents in batches of 100-500. Single-document adds are 10-50x slower due to index rebuild overhead. ChromaDB and pgvector both support batch operations.

7. **Test Retrieval Quality Before Deployment**: Create a test set of 10+ known question-answer pairs. Query the vector database and verify the correct document appears in the top 5 results for each question. If recall <80%, tune chunking, embedding model, or add hybrid search.

## Decision Framework

### When to Use Each Vector Database

```
What are the constraints?
|
+-- Prototyping or development
|   --> ChromaDB (embedded mode)
|       pip install chromadb
|       Zero config, persistent to disk
|       Limitation: single-process, no concurrent writers
|
+-- Production with <500K documents
|   --> ChromaDB (client-server mode) OR pgvector
|       ChromaDB server: `chroma run --host 0.0.0.0 --port 8000`
|       pgvector: if already using PostgreSQL
|
+-- Production with >500K documents
|   |
|   +-- Already using PostgreSQL? --> pgvector
|   +-- Need managed service?     --> Pinecone
|   +-- Self-hosted, open source? --> Weaviate
|
+-- Need SQL joins with vector search?
|   --> pgvector (only option for SQL + vectors in one query)
|
+-- Need zero-cost, fully local?
    --> ChromaDB embedded (no API costs, no network)
```

### Hybrid Search Decision

```
Is pure vector search returning good results?
|
+-- YES (recall >80%, precision >60%)
|   --> Stay with vector-only search. Hybrid adds complexity.
|
+-- NO, domain has specific terms/codes not captured by embeddings
|   --> Add keyword search (BM25) alongside vector search
|       ChromaDB: use `where` metadata filters + vector query
|       pgvector: use full-text search (tsvector) + vector similarity
|       Combine: weighted score = 0.7 * vector_score + 0.3 * keyword_score
|
+-- NO, results are topically correct but wrong specifics
    --> Improve chunking (smaller chunks, more overlap)
        OR switch to a better embedding model
        OR add metadata filters to narrow scope
```

## Procedures

### Procedure 1: Set Up ChromaDB for a Project

1. **Install and initialize**:
   ```python
   pip install chromadb

   import chromadb

   # Persistent storage (recommended for all projects)
   client = chromadb.PersistentClient(path="./chroma_data")

   # Create collection with cosine similarity
   collection = client.get_or_create_collection(
       name="project-docs",
       metadata={
           "hnsw:space": "cosine",
           "embedding_model": "all-MiniLM-L6-v2"
       }
   )
   ```

2. **Ingest documents in batches**:
   ```python
   from datetime import datetime

   def ingest_documents(collection, documents: list[dict], batch_size: int = 100):
       """Ingest documents with metadata in batches."""
       for i in range(0, len(documents), batch_size):
           batch = documents[i:i + batch_size]
           collection.add(
               documents=[d["content"] for d in batch],
               ids=[d["id"] for d in batch],
               metadatas=[{
                   "source": d["source"],
                   "content_type": d.get("content_type", "text"),
                   "last_updated": datetime.utcnow().isoformat(),
                   "user_id": d.get("user_id", "system")
               } for d in batch]
           )
       print(f"Ingested {len(documents)} documents in {len(documents) // batch_size + 1} batches")
   ```

3. **Query with metadata filtering**:
   ```python
   def query_scoped(collection, query: str, user_id: str, n_results: int = 5) -> list:
       """Query with user-scoped filtering."""
       results = collection.query(
           query_texts=[query],
           n_results=n_results,
           where={"user_id": {"$in": [user_id, "system"]}},  # User's docs + system docs
           include=["documents", "metadatas", "distances"]
       )

       formatted = []
       for doc, meta, dist in zip(
           results["documents"][0],
           results["metadatas"][0],
           results["distances"][0]
       ):
           formatted.append({
               "content": doc,
               "source": meta["source"],
               "relevance": round(1 - dist, 3),  # Convert distance to similarity
               "last_updated": meta["last_updated"]
           })

       return formatted
   ```

### Procedure 2: Set Up pgvector for Production

1. **Enable the extension**:
   ```sql
   CREATE EXTENSION IF NOT EXISTS vector;
   ```

2. **Create the embeddings table**:
   ```sql
   CREATE TABLE document_embeddings (
       id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
       document_id UUID NOT NULL REFERENCES documents(id),
       chunk_index INTEGER NOT NULL,
       content TEXT NOT NULL,
       embedding vector(384),  -- Match your embedding model dimension
       metadata JSONB DEFAULT '{}',
       created_at TIMESTAMP DEFAULT NOW(),
       UNIQUE(document_id, chunk_index)
   );

   -- Create HNSW index for fast similarity search
   CREATE INDEX ON document_embeddings
       USING hnsw (embedding vector_cosine_ops)
       WITH (m = 16, ef_construction = 200);
   ```

3. **Query with SQLAlchemy**:
   ```python
   from sqlalchemy import text

   async def vector_search(session, query_embedding: list[float], user_id: str, limit: int = 5):
       result = await session.execute(
           text("""
               SELECT de.content, de.metadata, d.filename,
                      1 - (de.embedding <=> :query_vec::vector) AS similarity
               FROM document_embeddings de
               JOIN documents d ON de.document_id = d.id
               WHERE d.user_id = :user_id
               ORDER BY de.embedding <=> :query_vec::vector
               LIMIT :limit
           """),
           {
               "query_vec": str(query_embedding),
               "user_id": user_id,
               "limit": limit
           }
       )
       return result.fetchall()
   ```

### Procedure 3: Implement Hybrid Search

1. **Combine vector + keyword with weighted scoring**:
   ```python
   async def hybrid_search(query: str, user_id: str, n_results: int = 5):
       # Vector search
       vector_results = collection.query(
           query_texts=[query],
           n_results=n_results * 2,  # Over-fetch for re-ranking
           where={"user_id": {"$in": [user_id, "system"]}},
           include=["documents", "metadatas", "distances"]
       )

       # Keyword search (simple substring matching on metadata)
       keyword_results = collection.get(
           where={
               "$and": [
                   {"user_id": {"$in": [user_id, "system"]}},
                   # ChromaDB supports $contains for metadata string matching
               ]
           },
           include=["documents", "metadatas"]
       )

       # Combine scores (weighted)
       VECTOR_WEIGHT = 0.7
       KEYWORD_WEIGHT = 0.3

       combined = merge_and_rank(vector_results, keyword_results, VECTOR_WEIGHT, KEYWORD_WEIGHT)
       return combined[:n_results]
   ```

## Reference Tables

### Vector Database Comparison

| Feature | ChromaDB | pgvector | Pinecone | Weaviate |
|---------|----------|----------|----------|----------|
| Deployment | Embedded / Server | PostgreSQL extension | Cloud managed | Self-hosted / Cloud |
| Setup complexity | Zero config | PostgreSQL required | Account signup | Docker compose |
| Max documents | ~1M (practical) | ~10M+ | Unlimited | ~10M+ |
| Query latency (1M docs) | 10-50ms | 5-20ms | 5-20ms | 10-30ms |
| Hybrid search | Metadata filters | Full-text + vector | Sparse + dense | Built-in BM25 + vector |
| Cost | Free | Free (self-hosted) | $70/mo+ | Free (self-hosted) |
| Best for | Prototyping, small prod | PostgreSQL shops | Managed prod | Self-hosted prod |

### HNSW Index Tuning Parameters

| Parameter | Default | Range | Effect |
|-----------|---------|-------|--------|
| `m` | 16 | 8-64 | Higher = more accurate, more memory. 16 is good default. |
| `ef_construction` | 200 | 64-512 | Higher = better index quality, slower build. 200 is good default. |
| `ef_search` | 50 | 10-500 | Higher = more accurate search, slower query. Tune for latency/recall tradeoff. |

### Embedding Dimension by Model

| Model | Dimensions | Storage per 1M docs |
|-------|-----------|-------------------|
| all-MiniLM-L6-v2 | 384 | ~1.5 GB |
| text-embedding-3-small | 1536 | ~6 GB |
| text-embedding-3-large | 3072 | ~12 GB |
| nomic-embed-text | 768 | ~3 GB |

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| Embedding model mismatch | All queries return low relevance scores, results seem random | Different embedding model used for ingestion vs query | Store embedding model in collection metadata. Verify match before querying. Re-embed if mismatch detected. |
| Collection not persisted | Data lost after restart, collection empty | Using ephemeral (in-memory) client instead of PersistentClient | Switch to `chromadb.PersistentClient(path="./chroma_data")`. Verify path exists and is writable. |
| Slow ingestion | Adding 10K documents takes >10 minutes | Single-document adds instead of batch operations | Use batch adds with batch_size=100-500. Use `collection.add()` with lists, not loops of single adds. |
| Out of memory | Process killed, or OOM errors during query | Index too large for available RAM, or too many concurrent queries | Increase available memory. Use IVF index for >1M docs. Limit concurrent queries. |
| Cross-user data leak | User sees documents from another user in search results | No user_id metadata filter on queries | Add `where={"user_id": user_id}` to every query. Verify with cross-user test cases. Audit existing queries. |
| Stale data in results | Agent cites outdated information confidently | Documents updated but embeddings not re-generated | Track `last_updated` metadata. Re-embed documents on update. Implement document expiration check. |

## Examples

### Example 1: Complete ChromaDB Setup for a Q&A Application

**Scenario**: 500 markdown files, ~50K chunks, single-user prototype.

**Setup**:
```python
import chromadb
from langchain_text_splitters import RecursiveCharacterTextSplitter

client = chromadb.PersistentClient(path="./chroma_data")
collection = client.get_or_create_collection(
    name="qa-docs",
    metadata={"hnsw:space": "cosine", "embedding_model": "all-MiniLM-L6-v2"}
)

splitter = RecursiveCharacterTextSplitter(chunk_size=512, chunk_overlap=64)

# Ingest all files
for filepath in glob("docs/**/*.md"):
    text = open(filepath).read()
    chunks = splitter.split_text(text)
    collection.add(
        documents=chunks,
        ids=[f"{filepath}_chunk_{i}" for i in range(len(chunks))],
        metadatas=[{"source": filepath, "content_type": "markdown",
                    "last_updated": "2026-02-20", "user_id": "system"}
                   for _ in chunks]
    )

# Verify: 50K chunks, ~20MB on disk, query latency: 15ms
print(f"Collection size: {collection.count()}")
```

**Query test**: 10 known Q&A pairs, recall@5 = 88%, precision@5 = 72%. PASS.
