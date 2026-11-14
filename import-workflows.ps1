docker exec n8n rm -rf /tmp/wf
docker cp n8n-workflows n8n:/tmp/wf
docker exec n8n sh -c "rm -f /tmp/wf/01-ai-chat.json"
docker exec n8n n8n import:workflow --separate --input=/tmp/wf
docker exec n8n n8n update:workflow --all --active=true
docker restart n8n
