---
name: vector-databases
description: Installation, configuration, and usage of ChromaDB, pgvector, and the ChromaDB MCP server for building RAG pipelines in AI-centric applications.
user-invocable: false
---

# Vector Database Tools

## Purpose

Enable Claude to install, configure, and operate vector databases (ChromaDB as primary, pgvector as production alternative) and the ChromaDB MCP server for RAG pipeline development and testing.

## Key Rules

1. **ChromaDB Is the Primary Tool**: Use ChromaDB for all RAG development. Switch to pgvector only when the project uses PostgreSQL and needs SQL joins with vector search.
2. **Always Use PersistentClient**: Never use `chromadb.Client()` (ephemeral). Always use `chromadb.PersistentClient(path="./chroma_data")` to persist across restarts.
3. **Pin ChromaDB Version**: ChromaDB API changes between major versions. Pin in requirements.txt: `chromadb>=1.0.0,<2.0.0`.

## Procedures

### Procedure 1: ChromaDB Setup and Operations

1. **Install and verify**:
   ```bash
   pip install chromadb
   python -c "import chromadb; print(f'ChromaDB {chromadb.__version__}'); c = chromadb.PersistentClient('./test_chroma'); col = c.get_or_create_collection('test'); col.add(documents=['hello world'], ids=['1']); r = col.query(query_texts=['hello'], n_results=1); print(f'Query result: {r[\"documents\"][0][0]}'); print('ChromaDB: OK')"
   ```
   Expected: Version printed, "hello world" returned, "OK" printed.

2. **Create a collection**:
   ```python
   import chromadb

   client = chromadb.PersistentClient(path="./chroma_data")
   collection = client.get_or_create_collection(
       name="project-docs",
       metadata={"hnsw:space": "cosine"}
   )
   ```

3. **Add documents (batch)**:
   ```python
   collection.add(
       documents=["Document text 1", "Document text 2", "Document text 3"],
       ids=["doc_1", "doc_2", "doc_3"],
       metadatas=[
           {"source": "file1.md", "user_id": "user_123"},
           {"source": "file2.md", "user_id": "user_123"},
           {"source": "file3.md", "user_id": "system"}
       ]
   )
   ```

4. **Query with filters**:
   ```python
   results = collection.query(
       query_texts=["search query"],
       n_results=5,
       where={"user_id": {"$in": ["user_123", "system"]}},
       include=["documents", "metadatas", "distances"]
   )
   ```

5. **Update documents**:
   ```python
   collection.update(
       ids=["doc_1"],
       documents=["Updated text"],
       metadatas=[{"source": "file1.md", "user_id": "user_123", "last_updated": "2026-02-20"}]
   )
   ```

6. **Delete documents**:
   ```python
   collection.delete(ids=["doc_3"])
   # Or delete by filter:
   collection.delete(where={"source": "file3.md"})
   ```

### Procedure 2: ChromaDB MCP Server

1. **Install and configure**:
   ```json
   {
     "mcpServers": {
       "chroma": {
         "command": "uvx",
         "args": ["chroma-mcp"],
         "env": {}
       }
     }
   }
   ```

2. **MCP tool reference**:

   | Function | Parameters | Returns | Use When |
   |----------|-----------|---------|----------|
   | `create_collection` | `name: str, metadata: dict` | Collection info | Setting up a new document set |
   | `add_documents` | `collection: str, documents: list, ids: list, metadatas: list` | Success status | Ingesting documents |
   | `query_collection` | `collection: str, query_texts: list, n_results: int, where: dict` | Ranked results | Searching for relevant content |
   | `list_collections` | None | Collection list | Checking available collections |
   | `get_collection_info` | `collection: str` | Count, metadata | Verifying collection state |
   | `delete_collection` | `collection: str` | Success status | Cleaning up |

3. **Example MCP usage**:
   ```
   Step 1: mcp__chroma__create_collection(name="test-docs", metadata={"hnsw:space": "cosine"})
   Step 2: mcp__chroma__add_documents(collection="test-docs", documents=["text"], ids=["1"], metadatas=[{"source": "test"}])
   Step 3: mcp__chroma__query_collection(collection="test-docs", query_texts=["search"], n_results=3)
   ```

### Procedure 3: pgvector Setup

1. **Install PostgreSQL extension**:
   ```sql
   -- In PostgreSQL:
   CREATE EXTENSION IF NOT EXISTS vector;
   ```

2. **Install Python client**:
   ```bash
   pip install pgvector sqlalchemy
   ```

3. **Create table with vector column**:
   ```sql
   CREATE TABLE embeddings (
       id SERIAL PRIMARY KEY,
       content TEXT NOT NULL,
       embedding vector(384),  -- dimension must match your model
       metadata JSONB DEFAULT '{}',
       created_at TIMESTAMP DEFAULT NOW()
   );

   CREATE INDEX ON embeddings USING hnsw (embedding vector_cosine_ops);
   ```

4. **Insert and query with SQLAlchemy**:
   ```python
   from pgvector.sqlalchemy import Vector
   from sqlalchemy import Column, Integer, String, create_engine
   from sqlalchemy.orm import declarative_base, Session

   Base = declarative_base()

   class Embedding(Base):
       __tablename__ = "embeddings"
       id = Column(Integer, primary_key=True)
       content = Column(String)
       embedding = Column(Vector(384))

   # Insert
   session.add(Embedding(content="hello", embedding=[0.1, 0.2, ...]))
   session.commit()

   # Query (nearest neighbor)
   from sqlalchemy import text
   results = session.query(Embedding).order_by(
       Embedding.embedding.cosine_distance([0.1, 0.2, ...])
   ).limit(5).all()
   ```

## Reference Tables

### ChromaDB Query Filter Operators

| Operator | Example | Description |
|----------|---------|-------------|
| `$eq` | `{"field": {"$eq": "value"}}` | Equals |
| `$ne` | `{"field": {"$ne": "value"}}` | Not equals |
| `$gt` | `{"field": {"$gt": 5}}` | Greater than |
| `$gte` | `{"field": {"$gte": 5}}` | Greater than or equal |
| `$lt` | `{"field": {"$lt": 10}}` | Less than |
| `$in` | `{"field": {"$in": ["a", "b"]}}` | In list |
| `$nin` | `{"field": {"$nin": ["a"]}}` | Not in list |
| `$and` | `{"$and": [filter1, filter2]}` | AND combination |
| `$or` | `{"$or": [filter1, filter2]}` | OR combination |

### ChromaDB Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `DuplicateIDError` | ID already exists in collection | Use `upsert()` instead of `add()`, or check with `get()` first |
| `ValueError: Embedding dimension mismatch` | Document embedded with different model than collection | Use same embedding model for all operations. Re-embed if needed. |
| `NotEnoughElementsException` | `n_results` > number of documents in collection | Reduce `n_results` or check `collection.count()` first |
| `InvalidCollectionException` | Collection name has invalid characters | Use lowercase, hyphens, no spaces: `my-collection` |

## Failure Modes

| Failure | Symptoms | Root Cause | Fix |
|---------|----------|------------|-----|
| Data lost after restart | Collection empty on next run | Using ephemeral `Client()` instead of `PersistentClient()` | Switch to `PersistentClient(path="./chroma_data")`. Verify path is writable. |
| Slow queries on large collection | Query takes >1s for >100K docs | Default HNSW parameters not tuned | Increase `ef_search` parameter. Consider server mode for large collections. |
| ChromaDB MCP server not responding | MCP tool calls fail with connection error | Server not started, or uvx not available | Verify `uvx` is installed. Run `uvx chroma-mcp` manually to test. Check MCP config JSON syntax. |
| pgvector index not used | Queries scan full table, very slow | Index not created, or wrong operator used | Create HNSW index. Use `<=>` operator for cosine distance. Run `EXPLAIN ANALYZE` to verify index usage. |
| Concurrent write conflicts | ChromaDB raises lock errors | Multiple processes writing to same PersistentClient | Use ChromaDB server mode for multi-process access. Or serialize writes through a queue. |

## Examples

### Example 1: Complete RAG Setup with ChromaDB

```python
import chromadb
from langchain_text_splitters import RecursiveCharacterTextSplitter

# Initialize
client = chromadb.PersistentClient(path="./chroma_data")
collection = client.get_or_create_collection("docs", metadata={"hnsw:space": "cosine"})

# Chunk and ingest
splitter = RecursiveCharacterTextSplitter(chunk_size=512, chunk_overlap=64)
for filepath in ["README.md", "docs/guide.md"]:
    chunks = splitter.split_text(open(filepath).read())
    collection.add(
        documents=chunks,
        ids=[f"{filepath}_{i}" for i in range(len(chunks))],
        metadatas=[{"source": filepath, "user_id": "system"} for _ in chunks]
    )

# Query
results = collection.query(query_texts=["how to install"], n_results=5)
for doc, score in zip(results["documents"][0], results["distances"][0]):
    print(f"[{1-score:.2f}] {doc[:100]}...")
```
