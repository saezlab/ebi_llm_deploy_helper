#!/bin/bash
session_name="server"
socket_path="$HOME/tmux_socket"

user_name=$(whoami)
hostname=$(hostname)

echo "------------------------------------------------------------"
echo "✔ A compute node has been allocated and locked for your use."
echo "------------------------------------------------------------"

# Detect GPUs using nvidia-smi
if command -v nvidia-smi &> /dev/null; then
    gpu_info=$(nvidia-smi --query-gpu=name --format=csv,noheader | sort | uniq -c | sed 's/^ *//; s/ /x /')
    gpu_count=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
    echo "• GPU configuration detected: ${gpu_info}"
else
    echo "! No NVIDIA GPUs detected (or 'nvidia-smi' not available)."
fi

# Detect available port starting from 8000
used_ports=$(ss -tln | awk 'NR>1 {print $4}' | cut -d':' -f2 | sort -n | uniq | grep -v '^$')
available_port=""
for port in $(seq 8000 30000); do
    if ! echo "$used_ports" | grep -q "^${port}$"; then
        available_port=$port
        break
    fi
done
if [ -n "$available_port" ]; then
    echo "• Available port: $available_port"
else
    echo "! No available port found (checked 8000-30000)."
fi

echo ""
echo "------------------------------------------------------------"
echo "  Next Steps"
echo "------------------------------------------------------------"
echo "  [1] Open another terminal and run the following to start a detachable shell:"
echo "\`\`\`"
echo "ssh -t -L 8000:localhost:$available_port $user_name@$hostname tmux -S ~/tmux_socket new -A -s server"
echo "\`\`\`"
echo ""
echo "  [2] Launch OpenAI OSS-120B using vLLM:"
echo "\`\`\`"
echo "cd /hps/nobackup/saezrodriguez/hf_models && \\"
echo "singularity exec --nv ../singularity_images/vllm-openai_latest.sif \\"
echo "  vllm serve ./gpt-oss-120b --tensor-parallel-size $gpu_count --port $available_port \\"
echo "    --enable-auto-tool-choice --tool-call-parser openai --reasoning-parser openai-oss"
echo "\`\`\`"
echo "      For more information, refer to the crash course at <URL HERE>."
echo ""
echo "  [3] Once your server has started, the base URL of theOpenAI compatible API is as follows."
echo "\`\`\`
echo "http://localhost:$available_port/v1/"
echo "\`\`\`"
echo ""
echo "  [4] You can ignore this terminal or close it — it will exit automatically once the server session ends."
echo "      If you want to release the compute node manually, press Ctrl-C here"
echo ""


echo "------------------------------------------------------------"
echo "Waiting for tmux session '$session_name' (socket: $socket_path)..."
echo "------------------------------------------------------------"

# Wait until the session is created
until tmux -S "$socket_path" has-session -t "$session_name" 2>/dev/null; do
    sleep 1
done

echo ""
echo "✔ tmux session '$session_name' detected. Monitoring until it ends..."
echo ""

while tmux -S "$socket_path" has-session -t "$session_name" 2>/dev/null; do
    sleep 1
done

echo ""
echo "------------------------------------------------------------"
echo "tmux session '$session_name' has ended. Releasing compute node."
echo "------------------------------------------------------------"
exit 0
