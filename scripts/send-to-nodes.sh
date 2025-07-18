#!/bin/bash

# Lista de plugins como argumentos
PLUGINS=("$@")
if [ ${#PLUGINS[@]} -eq 0 ]; then
    echo "❌ Nenhum plugin informado!"
    exit 1
fi

REMOTE_TMP_DIR="/root/tmp-plugins"
PTERO_VOLUME_PATH="/var/lib/pterodactyl/volumes"

# Lista de nodes no formato: IP USER SENHA PORTA
NODES=(
    "node1.hight.systems root Hight@123_ 2123"
    "node2.hight.systems root Hight@123_ 2123"
)

for node in "${NODES[@]}"; do
    IFS=' ' read -r HOST USER PASS PORT <<< "$node"

    echo "🚀 Conectando na node $HOST:$PORT..."

    echo "📤 Enviando plugins via SFTP..."
    sshpass -p "$PASS" sftp -o StrictHostKeyChecking=no -o Port=$PORT "$USER@$HOST" <<EOF
mkdir -p $REMOTE_TMP_DIR
$(for plugin in "${PLUGINS[@]}"; do echo "put /var/jenkins_home/workspace/pandaspigot/$plugin $REMOTE_TMP_DIR/$plugin"; done)
bye
EOF

    echo "🔐 Entrando via SSH..."
    sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -p $PORT "$USER@$HOST" bash -s <<EOF
PLUGINS=(${PLUGINS[@]})
REMOTE_TMP_DIR="$REMOTE_TMP_DIR"
PTERO_VOLUME_PATH="$PTERO_VOLUME_PATH"
declare -A AFFECTED_CONTAINERS  # Usando um array associativo para evitar duplicatas

for PLUGIN_NAME in "\${PLUGINS[@]}"; do
    echo "🔍 Procurando plugin \$PLUGIN_NAME..."
    while IFS= read -r plugin_path; do
        echo "📦 Substituindo \$PLUGIN_NAME em: \$plugin_path"
        cp "\$REMOTE_TMP_DIR/\$PLUGIN_NAME" "\$plugin_path"

        # Extrai o server_id do caminho (assumindo que está na 6ª posição)
        server_id=\$(echo "\$plugin_path" | awk -F'/' '{print \$6}')

        if [[ -n "\$server_id" ]]; then
            AFFECTED_CONTAINERS["\$server_id"]=1
        fi
    done < <(find "\$PTERO_VOLUME_PATH" -type f -name "\$PLUGIN_NAME" 2>/dev/null)
done

# Reinicia todos os containers afetados
for id in "\${!AFFECTED_CONTAINERS[@]}"; do
    echo "♻️ Reiniciando container: \$id"
    docker container restart "\$id" 2>/dev/null
done

echo "✅ Deploy concluído nesta node!"
EOF

    echo "🌟 Node $HOST finalizada!"
done

echo "🏁 Todas as nodes foram atualizadas com sucesso!"
