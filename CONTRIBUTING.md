# Contributing to Universal Vault

Thank you for your interest in improving **Universal Vault**! We welcome contributions from developers, security researchers, and designers worldwide.

---

## 🚀 How to Contribute

### 1. Reporting Bugs
* Check existing issues before submitting a new bug report.
* Provide a minimal reproducible example (e.g., file type, file size, OS environment, and launcher used).
* Include terminal output or browser console logs if applicable.

### 2. Feature Requests & Proposals
* Open an issue with the `[Feature]` tag describing the use-case and proposed architectural design.
* We prioritize features that preserve **zero-install portability**, **in-place stream performance**, and **cryptographic rigor**.

### 3. Pull Requests
1. Fork the repository on GitHub: `https://github.com/Adil-Arbaz-Khan/Universal-Vault`
2. Create a topic branch: `git checkout -b feature/my-new-feature`
3. Ensure your code passes all cryptographic tests:
   ```bash
   # Test PowerShell Engine
   powershell -File tools/header_vault.ps1 -Action Lock -Path Test_Samples -Password "testpass"
   powershell -File tools/header_vault.ps1 -Action Unlock -Path Test_Samples -Password "testpass"

   # Test Python Engine
   python tools/vault.py lock Test_Samples -p "testpass"
   python tools/vault.py unlock Test_Samples -p "testpass"
   ```
4. Commit your changes with clear, descriptive commit messages.
5. Push to your fork and submit a Pull Request against `main`.

---

## 📐 Code Style & Guidelines

* **Zero External Dependencies**: Keep core PowerShell and Python scripts functional using standard built-in libraries where possible (with graceful fallbacks for `cryptography` / `pycryptodome`).
* **Cross-Platform Parity**: Any changes made to the `VAULTV05` binary specification must be implemented simultaneously across:
  1. `tools/header_vault.ps1` (PowerShell .NET)
  2. `tools/vault.py` (Python 3.8+)
  3. `Vault_App.html` (WebCrypto & Pure JS)
  4. Batch & Shell wrapper scripts

---

## 📜 License

By contributing to Universal Vault, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).
