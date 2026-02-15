# Ì¥ù Contributing to Obsidian Arcadia Network

## Getting Started

### Fork and Clone
```bash
git clone https://github.com/your-username/Obsidian-Arcadia-Network.git
cd Obsidian-Arcadia-Network
```

### Install Dev Dependencies
```bash
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -e ".[dev]"
```

### Run Tests
```bash
python run_all_tests.py
```

## Code Style

- Follow PEP 8
- Use Black for formatting
- Add tests for new features
- Update documentation
```bash
black oan/ tests/
flake8 oan/ tests/
```

## Pull Request Process

1. Create branch: `git checkout -b feature/my-feature`
2. Make changes and add tests
3. Run tests: `python run_all_tests.py`
4. Commit: `git commit -m "Add: Feature description"`
5. Push: `git push origin feature/my-feature`
6. Create Pull Request on GitHub

## Commit Messages

- `Add:` New feature
- `Fix:` Bug fix
- `Update:` Documentation/dependencies
- `Refactor:` Code cleanup

## Adding Examples

1. Create `.obs` file in `examples/`
2. Add to `EXAMPLES.md`
3. Test it works
4. Submit PR

## Questions?

- Check documentation first
- Search existing issues
- Create new issue with details

## Thank You! Ìπè

Every contribution helps make OAN better!

**Happy coding!** Ìºë
