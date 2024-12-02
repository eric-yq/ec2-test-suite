# Create Milvus client
from pymilvus import MilvusClient
milvus_client = MilvusClient(
    uri="http://localhost:19530"
)
collection_name = "milvus_docs"

# Load an embedding model:
from langchain_huggingface import HuggingFaceEmbeddings
embedding_model = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")

# Ask questions and get the answer:
import sys
question = sys.argv[1]
# question = "This is a default question for demo: give a introduction to Milvus and RAG."
# print("Question: ", question)
search_res = milvus_client.search(
    collection_name=collection_name,
    data=[
        embedding_model.embed_query(question)
    ],  # Use the `emb_text` function to convert the question to an embedding vector
    limit=10,  # Return top 10 results
    search_params={"metric_type": "IP", "params": {}},  # Inner product distance
    output_fields=["text"],  # Return the text field
)

import json
retrieved_lines_with_distances = [
    (res["entity"]["text"], res["distance"]) for res in search_res[0]
]
# print(json.dumps(retrieved_lines_with_distances, indent=4))

# Use the LLM to obtain a RAG response, and answer the questions:
from openai import OpenAI
llm_client = OpenAI(base_url="http://localhost:8080/v1", api_key="no-key")

context = "\n".join(
    [line_with_distance[0] for line_with_distance in retrieved_lines_with_distances]
)

SYSTEM_PROMPT = """
Human: You are an AI assistant. You are able to find answers to the questions from the contextual passage snippets provided.
"""
USER_PROMPT = f"""
Use the following pieces of information enclosed in <context> tags to provide an answer to the question enclosed in <question> tags.
<context>
{context}
</context>
<question>
{question}
</question>
"""

response = llm_client.chat.completions.create(
    model="not-used",
    messages=[
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": USER_PROMPT},
    ],
    stream=True,
)
# print("Answer: ", response.choices[0].message.content)
for chunk in response:
  print(chunk.choices[0].delta.content or "", end="")
  