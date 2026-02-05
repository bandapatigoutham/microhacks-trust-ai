# Streamlit Chat Application

A simple chat interface that uses Azure OpenAI with managed identity authentication, designed to run on Azure Container Apps.

## Features

- 💬 **Streaming Chat Responses**: Real-time streaming of AI responses
- 🔐 **Managed Identity Authentication**: Secure keyless authentication using Azure AD
- 📝 **Conversation History**: Maintains chat context within the session
- 🐳 **Azure Container Apps Ready**: Containerized deployment with nginx reverse proxy
- 🔌 **REST API**: FastAPI backend for programmatic access

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Azure Container Apps                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   nginx (port 8080)                 │    │
│  │         ┌──────────────┬──────────────┐             │    │
│  │         │   /          │   /api/*     │             │    │
│  │         │   /chat      │   /chat      │             │    │
│  │         ▼              ▼              │             │    │
│  │  ┌──────────┐    ┌──────────┐         │             │    │
│  │  │Streamlit │    │ FastAPI  │         │             │    │
│  │  │ (8501)   │    │ (8000)   │         │             │    │
│  │  └────┬─────┘    └────┬─────┘         │             │    │
│  │       └───────┬───────┘               │             │    │
│  │               ▼                       │             │    │
│  │       Azure OpenAI Client             │             │    │
│  │                                       │             │    │
│  │       User Assigned Managed Identity  │             │    │
│  └───────────────────────────────────────┘             │    │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
                ┌──────────────────────────┐
                │    Azure OpenAI          │
                │    (Cognitive Services)  │
                │                          │
                │  • gpt-4o-mini           │
                │  • Managed Identity Auth │
                └──────────────────────────┘
```

## Prerequisites

- Azure subscription
- Azure CLI installed
- azd CLI installed
- Docker (for local container testing)
- Python 3.11+

## Local Development  on Mac OS X or Linux

0. **Navigate to the `app` directory 
   ```bash
   cd app

   ```
1. **Set environment variables on Mac OS X or Linux:**
   ```bash
   export AZURE_OPENAI_ENDPOINT="https://your-openai-service.openai.azure.com/"
   export AZURE_OPENAI_CHAT_DEPLOYMENT="gpt-4o-mini"
   ```

2. **Install dependencies:**
   ```bash
   # Create a Local Environment
   python3 -m venv .localenv

   # Activate the Virtual Environment
   source .localenv/bin/activate

   # Update your local PIP version to the latest
   pip install --upgrade pip

   # Install the Python dependencies into the local environment 
   pip install -r requirements.txt
   ```

3. **Run locally:**
   ```bash
   # Run Streamlit UI
   streamlit run app.py
   
   # Or run FastAPI REST API
   uvicorn api:app --reload
   ```

   - Streamlit UI: `http://localhost:8501`
   - FastAPI: `http://localhost:8000`
   - API Docs: `http://localhost:8000/docs`

4. **Run with Docker:**
   ```bash
   docker build -t chat-app .
   docker run -p 8080:8080 \
     -e AZURE_OPENAI_ENDPOINT="https://your-openai-service.openai.azure.com/" \
     -e AZURE_OPENAI_CHAT_DEPLOYMENT="gpt-4o-mini" \
     chat-app
   ```

## REST API Usage

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | API information |
| GET | `/api/health` | Health check |
| POST | `/chat` | Send message, get complete response |
| POST | `/chat/stream` | Send message, get streaming response |

### Example: Send a chat message

```bash
curl -X POST "http://localhost:8080/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What is Azure OpenAI?",
    "conversation_history": [],
    "temperature": 0.7
  }'
```

### Example: Chat with conversation history

```bash
curl -X POST "http://localhost:8080/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Can you explain more?",
    "conversation_history": [
      {"role": "user", "content": "What is Azure?"},
      {"role": "assistant", "content": "Azure is Microsoft cloud platform..."}
    ]
  }'
```

### Example: Streaming response

```bash
curl -X POST "http://localhost:8080/chat/stream" \
  -H "Content-Type: application/json" \
  -d '{"message": "Tell me a short story"}'
```

## Deployment to Azure

### Using the deployment script

1. **Provision infrastructure (if not already done):**
   ```bash
   azd up
   ```

2. **Deploy the Container App:**
   ```bash
   cd scripts
   ./06_deploy_container_apps.sh
   ```

## Configuration

The app uses the following environment variables (set automatically by Bicep):

| Variable | Description |
|----------|-------------|
| `AZURE_OPENAI_ENDPOINT` | Azure OpenAI service endpoint URL |
| `AZURE_OPENAI_CHAT_DEPLOYMENT` | Model deployment name (default: gpt-4o-mini) |
| `AZURE_CLIENT_ID` | User-assigned managed identity client ID |

## Authentication

The application uses **Azure Managed Identity** for authentication:

- **In Azure Container Apps**: User-assigned managed identity is configured for the container
- **Locally**: Azure CLI credentials are used via `DefaultAzureCredential`

The managed identity is granted the `Cognitive Services OpenAI User` role on the Azure OpenAI resource during infrastructure provisioning.

## Troubleshooting

### View application logs

```bash
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <rg-name> \
  --follow
```

### Common issues

1. **401 Unauthorized**: The managed identity may not have proper permissions. Verify the role assignment in Azure portal.

2. **Container not starting**: Check the container logs. Ensure the Docker image builds correctly and all environment variables are set.

3. **Timeout errors**: Azure OpenAI may be throttled. Check your TPM (tokens per minute) quota.

4. **502 Bad Gateway**: The application inside the container may not be ready. Check nginx and application startup logs.

## File Structure

```
app/
├── app.py              # Streamlit web UI application
├── api.py              # FastAPI REST API
├── Dockerfile          # Container image definition
├── nginx.conf          # nginx reverse proxy configuration
├── supervisord.conf    # Process manager for running multiple services
├── requirements.txt    # Python dependencies
├── startup.sh          # Container startup script (Streamlit)
├── startup_api.sh      # Container startup script (FastAPI)
└── README.md           # This file
```
