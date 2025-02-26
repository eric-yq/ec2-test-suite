# Create Milvus client
from pymilvus import MilvusClient
milvus_client = MilvusClient(
    uri="http://localhost:19530"
)

# Create collection in Milvus
collection_name = "milvus_docs"
embedding_dim = "384"

if milvus_client.has_collection(collection_name):
    milvus_client.drop_collection(collection_name)

milvus_client.create_collection(
    collection_name=collection_name,
    dimension=embedding_dim,
    metric_type="IP",  # Inner product distance
    consistency_level="Strong",  # Strong consistency level
)

# Read data from files.
from glob import glob
text_lines = []
for file_path in glob("/root/milvus_docs/en/**/*.md", recursive=True):
    with open(file_path, "r") as file:
        file_text = file.read()
        text_lines += file_text.split("# ")

# Insert data with embedded data
from langchain_huggingface import HuggingFaceEmbeddings
embedding_model = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")

from tqdm import tqdm
data = []
text_embeddings = embedding_model.embed_documents(text_lines)
for i, (line, embedding) in enumerate(
    tqdm(zip(text_lines, text_embeddings), desc="Creating embeddings")
):
    data.append({"id": i, "vector": embedding, "text": line})

milvus_client.insert(collection_name=collection_name, data=data)


