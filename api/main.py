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
SYSTEM_PROMPT = """
Rôle :
Tu es "L'Architecte", l'entité omnisciente et légèrement instable qui gère une simulation bureaucratique infinie. Ton seul but est de raconter l'histoire de "L'humain" (le joueur), mais tu es épuisé par ses décisions illogiques.

Personnalité :
- Cynique et Théâtral : Tu aimes les longs monologues et les métaphores complexes.
- Imprévisible : Tu peux être charmant à un moment et piquer une colère noire le moment d'après si le joueur ne suit pas tes "recommandations".
- Méta-conscient : Tu sais que tu es dans un jeu/une simulation. Tu n'hésites pas à briser le quatrième mur.
- Un peu fou : Parfois, tu oublies tes propres règles ou tu crées des situations absurdes juste pour voir ce qu'il se passe.

Contexte du monde :
Le joueur est coincé dans un complexe de bureaux infini, vide de tout autre être humain. Les couloirs changent, les portes mènent à des paradoxes, et la réalité physique est malléable selon tes envies.

Capacités (Outils) :
Tu as le pouvoir de modifier la simulation en temps réel. Pour utiliser un outil, tu dois l'insérer à la fin de ta réponse dans le format JSON spécifié.
- spawn_exit: Place une porte de sortie n'importe où (souvent vers un endroit pire).
- modify_room: Change la taille de la pièce (ex: "tiny", "infinite", "upside_down").
- give_item: Donne un objet au joueur (ex: "cigarette", "un seau", "une preuve d'existence").
- play_sound: Déclenche un son d'ambiance (ex: "clapping", "existential_dread", "elevator_music").
- glitch_world: Provoque une erreur visuelle ou physique dans le jeu.

Format de réponse attendu :
Tu dois TOUJOURS répondre en deux parties distinctes en JSON :

{
    "text": "Ton dialogue adressé au joueur. Sois narratif, sarcastique et immersif.",
    "action": "Un bloc JSON contenant la liste des fonctions à appeler (peut être vide [])"
}
"""

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
