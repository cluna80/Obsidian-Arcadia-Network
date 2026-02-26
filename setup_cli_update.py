import re

with open('setup.py', 'r') as f:
    content = f.read()

# Check if entry_points already exists
if 'entry_points' not in content:
    # Add entry_points before the closing )
    content = content.replace(
        ')',
        ''',
    entry_points={
        'console_scripts': [
            'oan=oan.cli:main',
        ],
    },
)''', 1)
    
    with open('setup.py', 'w') as f:
        f.write(content)
    print("✅ Added CLI entry point to setup.py")
else:
    print("✅ CLI entry point already exists")
