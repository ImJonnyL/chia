LLM servers, providers, and agent Nodes
=======================================

API reference for the LLM servers, providers, and agents library nodes in 
:mod:`chia.models`.

Base class
----------

.. automodule:: chia.base.llm_call
   :no-index:

Providers
---------

We provide the prompt interface for each of the following providers. Many of our interfaces for these providers are lightly tested using free tokens. In particular, error handling is likely fragile.

CLIs
~~~~

Claude :mod:`chia.models.claude`

Codex :mod:`chia.models.codex`

Copilot :mod:`chia.models.copilot`

OpenCode :mod:`chia.models.opencode`

When an explicit ``model`` is passed to ``OpenCodeLLM``, it also selects the
background model and all built-in agent models (including summary and
compaction). CHIA supplies a fixed session title to avoid a separate title
request, and its generated inline config takes precedence over inherited
inline model settings. Without an explicit model, OpenCode retains its own
model defaults. Other background requests may still incur costs not included
in exported session usage; the provider's activity records remain the billing
reference.

Antigravity :mod:`chia.models.antigravity`


Remote providers
~~~~~~~~~~~~~~~~

Bedrock :mod:`chia.models.bedrock`

Vertex :mod:`chia.models.vertex`

OpenAI :mod:`chia.models.openai_providers` :mod:`chia.models.openai_compat`

OpenRouter (OpenAI compatible) :mod:`chia.models.openai_providers` :mod:`chia.models.openai_compat`

FireworkAI (OpenAI compatible) :mod:`chia.models.openai_providers` :mod:`chia.models.openai_compat`

Groq (OpenAI compatible) :mod:`chia.models.openai_providers` :mod:`chia.models.openai_compat`


On-prem servers
~~~~~~~~~~~~~~~

VLLM :mod:`chia.models.vllm`

Ollama :mod:`chia.models.ollama`
