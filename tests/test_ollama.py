import ollama

response = ollama.chat(
    model='gemma3:12b',           # or 'llama3.2:3b' etc.
    messages=[
        {
            'role': 'user',
            'content': 'Hello from OAN! Give me one sentence about autonomous agents in Web3.',
        },
    ],
)

print(response['message']['content'])