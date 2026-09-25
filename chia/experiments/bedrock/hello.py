from chia.base.ChiaFunction import get
from chia.models.opencode import OpenCodeLLM

llm = OpenCodeLLM(
    model="amazon-bedrock/moonshotai.kimi-k2.5"
)

result = get(
    llm.prompt.chia_remote(
        llm,
        "Print exactly: Hello World. Scooby Doo."
    )
)

print(result.result)
