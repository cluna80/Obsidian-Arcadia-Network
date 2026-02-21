import ollama

response = ollama.chat(
    model='gemma3:12b',           # change to whatever model you actually pulled
    messages=[
        {
            'role': 'user',
            'content': 'Hello from OAN! Give me one sentence about autonomous agents in Web3.',
        },
    ],
)

print(response['message']['content'])
