# Step 1: Allocate GPU Compute Node

To start an LLM server on EBI's HPC, a small hack is required. I have prepared a script to make it easier.

## Allocate Resources

Run the following command on your terminal to allocate a GPU compute node:

```bash
ssh -t <your EBI username>@ihpc.ebi.ac.uk "tmux new -A -s sjob 'srun -t 4:00:00 -N1 --gres=gpu:a100:4 --cpus-per-task=16 --mem=32G sh /hps/nobackup/saezrodriguez/paul/auto_exit.sh'"
```

> **Note**: The command is deliberately written in one line for OS compatibility (Windows/Linux/Mac).

## Resource Configuration

You may tune the command to request the appropriate resources for your model:

- `-t 4:00:00` - How long you want to hold it (this example is 4 hours)
- `--gres=gpu:a100:4` - What kind of GPU and how many you want. You can only request: **A100** × [1-4] or **H200** × [1-8] (this example is 4 H200)
- `--cpus-per-task=16` - Total number of CPUs you want
- `--mem=32G` - Total RAM you want
- `-N1` - Requires all above to be on one single node, which will enforce the number of GPUs you requested, or otherwise it may give you less

### GPU Requirements

The larger your model, the more GPUs you need. A rough estimation would be: **1.25× of the model files total size** is roughly the minimum GPU VRAM you need.

# Step 2: Deploying LLM Server

The instructions from my script will give you an OpenAI model. Below is extra information for a more advanced deployment.

You now have a session running in the compute node and you have just entered the session. Next, you will start the LLM server.

There are currently two LLM server Docker images that you can use: **SGLang** and **vLLM**.

## Command Examples

The following are command examples for serving OpenAI OSS 120B using either one of them:

### SGLang

```bash
cd /hps/nobackup/saezrodriguez/hf_models && \
singularity exec --nv ../singularity_images/sglang_latest.sif \
  python -m sglang.launch_server \
    --tp-size <number of the GPUs> \
    --port <available port> \
    --model-path ./gpt-oss-120b \
    --tool-call-parser gpt-oss \
    --reasoning-parser gpt-oss
```

### vLLM

```bash
cd /hps/nobackup/saezrodriguez/hf_models && \
singularity exec --nv ../singularity_images/vllm-openai_latest.sif \
  vllm serve ./gpt-oss-120b \
    --tensor-parallel-size <number of the GPUs> \
    --port <available port> \
    --enable-auto-tool-choice \
    --tool-call-parser openai \
    --reasoning-parser openai
```

## Model split
The model can be split into multiple parts distributed across multiple GPUs. This combines multiple GPUs and their VRAM as a single unit, allowing you to deploy a larger model or run faster. The equivalent arguments for SGLang and vLLM are `--tp-size` and `--tensor-parallel-size` respectively. The number supplied should always equal the number of GPUs you have, unless you want to use other kinds of parallelism which is out of scope here.

Note that the number must evenly divide the model's tensor dimensions. Common options are 2, 4, or 8.

## Parser Configuration

Regardless of which server you use, you need to make sure the tool call or reasoning parser is correct. Due to different models being trained differently, they use different control tokens and therefore they need their own parsers. Refer to SGLang's or vLLM's documentation for the parsers available for their supported models.

### SGLang Documentation

- **Tool call**: [https://docs.sglang.ai/advanced_features/tool_parser.html](https://docs.sglang.ai/advanced_features/tool_parser.html)
- **Reasoning**: [https://docs.sglang.ai/advanced_features/separate_reasoning.html](https://docs.sglang.ai/advanced_features/separate_reasoning.html)

### vLLM Documentation

- **Tool call**: [https://docs.vllm.ai/en/stable/features/tool_calling.html](https://docs.vllm.ai/en/stable/features/tool_calling.html)
- **Reasoning**: [https://docs.vllm.ai/en/stable/features/reasoning_outputs.html](https://docs.vllm.ai/en/stable/features/reasoning_outputs.html)

> **Note**: Their documentations are sometimes outdated. Very often the model card will provide up-to-date guidance on what arguments are required to run correctly. For example, this one:
> 
> [https://huggingface.co/MiniMaxAI/MiniMax-M2#sglang](https://huggingface.co/MiniMaxAI/MiniMax-M2#sglang)

## Additional Server Arguments

There are other server arguments that you may find useful, such as:
- **Load balancing** (for serving many people)
- **Speculative decoding** (sacrifice precision for faster inference)

For all arguments available, refer to the links below:

- **SGLang**: [https://docs.sglang.ai/advanced_features/server_arguments.html](https://docs.sglang.ai/advanced_features/server_arguments.html)
- **vLLM**: [https://docs.vllm.ai/en/stable/cli/serve.html](https://docs.vllm.ai/en/stable/cli/serve.html)

## Choosing Between SGLang and vLLM

Most of the time both can serve you well, but sometimes you may find that one supports newly released models faster than the other.
