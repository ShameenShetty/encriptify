# Encriptify

**Encriptify** is a lightweight, high-performance desktop application built with Flutter that enables fast, secure file compression and encryption. Designed for speed and efficiency, Encriptify makes full use of all available CPU cores for accelerated processing — ensuring faster compression, decompression, encryption, and decryption.

---

## 🔐 Features

- **File Encryption & Decryption**  
  Secure files using strong encryption algorithms, ensuring your data remains private and protected.

- **File Compression & Decompression**  
  Reduce file sizes quickly and efficiently, supporting various compression levels.

- **Multi-core Processing**  
  Unlike most tools, Encriptify utilizes all available CPU cores, significantly speeding up compute-heavy tasks.

- **Cross-platform**  
  Built using Flutter, runs natively on Windows, macOS, and Linux.

---

## 🚀 Why Encriptify?

Traditional file utilities often run single-threaded and can be slow for large files. Encriptify is built to scale with your hardware — whether you're encrypting sensitive documents or compressing large backups, it completes the task faster by leveraging multi-core parallelism.

---

## 🛠️ How It Works

- Written in **Dart + Flutter Desktop**.
- Uses `compute()` and **isolates** for multi-threading.
- Built-in support for:
  - **AES encryption**
  - **ZIP/GZIP compression**
- Modular architecture for adding more algorithms in the future.

---

## 🧩 Tech Stack

- **Flutter Desktop**
- **Dart Isolates & compute()**
- Packages:
  - [`encrypt`](https://pub.dev/packages/encrypt) – encryption
  - [`archive`](https://pub.dev/packages/archive) – compression
  - [`flutter_file_dialog`](https://pub.dev/packages/flutter_file_dialog) – native file picker dialogs

---

## 📦 Roadmap

- [x] Multi-core compression/decompression
- [x] Multi-core encryption/decryption
- [ ] Drag-and-drop file UI
- [ ] Batch file processing
- [ ] Custom file format (`.enf` – Encriptify File)

---

## 🧪 Benchmarking

Coming soon: built-in benchmarking tool to compare performance against single-core tools like 7-Zip or Picocrypt.

---

## 📥 Installation

> (Instructions for downloading the latest release or building from source — TBD)

---

## 👤 Author

**Shameen Shetty**  
[GitHub](https://github.com/ShameenShetty)

---

## 🛡️ License

MIT License