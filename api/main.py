import os
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import List, Literal
from langchain_groq import ChatGroq
from langchain_core.messages import SystemMessage, HumanMessage, AIMessage

# Chargement des variables d'environnement
load_dotenv()

# Initialisation de l'application FastAPI
app = FastAPI(
    title="LLM Parable API",
    description="API utilisant LangChain et Groq pour le projet LLM Parable",
    version="1.0.0"
)

# Initialisation du modèle Groq
llm = ChatGroq(model="openai/gpt-oss-120b")

# Définition du prompt système
SYSTEM_PROMPT = "Tu es un assistant IA utile, concis et poli. Tu réponds aux questions de l'utilisateur."

# --- Modèles Pydantic ---

class Message(BaseModel):
    role: Literal["user", "assistant"]
    content: str

class ChatRequest(BaseModel):
    user_query: str = Field(..., description="La dernière question/requête de l'utilisateur")
    history: List[Message] = Field(default_factory=list, description="L'historique de la conversation")

class ChatResponse(BaseModel):
    response: str

# --- Endpoints ---

@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(request: ChatRequest):
    """
    Génère une réponse avec LangChain et Groq en reconstruisant l'historique complet.
    """
    messages = []
    
    # 1. On insère le prompt système en tout premier lieu
    messages.append(SystemMessage(content=SYSTEM_PROMPT))
    
    # 2. On reconstruit l'historique de conversation
    for msg in request.history:
        if msg.role == "user":
            messages.append(HumanMessage(content=msg.content))
        elif msg.role == "assistant":
            messages.append(AIMessage(content=msg.content))
            
    # 3. On ajoute la requête actuelle de l'utilisateur
    messages.append(HumanMessage(content=request.user_query))
    
    # 4. Appel de l'API Groq via LangChain
    try:
        response = llm.invoke(messages)
        return ChatResponse(response=response.content)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de l'appel à Groq: {str(e)}")

@app.get("/")
def root():
    return {"message": "Bienvenue sur l'API LLM Parable. Allez sur /docs pour voir les endpoints."}
