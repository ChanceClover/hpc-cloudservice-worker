# HPC Cloud Service Worker

Worker relawan menggunakan CPU perangkat Anda untuk menjalankan tugas dari koordinator HPC Cloud Service. Portal di repositori [hpc-cloudservice](https://github.com/NoelianGH/hpc-cloudservice) menangani registrasi relawan dan penerbitan token.

## Menjalankan worker

1. Siapkan Docker dengan Docker Compose. Di Windows, jalankan Docker Desktop dengan integrasi Ubuntu WSL2.
2. Daftar di halaman registrasi portal HPC Cloud Service yang disediakan tim. Selesaikan verifikasi OTP lalu salin token worker yang diterbitkan koordinator.
3. Dari folder repo worker, buat file konfigurasi lokal.

   ```bash
   cp .env.example .env
   ```

4. Isi `COORDINATOR_URL` dengan alamat HTTPS API koordinator yang diberikan tim. Tempel token individual ke `WORKER_TOKEN` dan isi `WORKER_NAME` dengan nama perangkat. Simpan token di `.env` lokal.
5. Bangun dan jalankan worker, lalu lihat lognya.

   ```bash
   docker compose up --build -d
   docker compose logs -f worker
   ```

   Log akan menampilkan identitas worker setelah terdaftar. Setelah koordinator menyediakan tugas dan menerima hasilnya, log akan menampilkan pesan tugas selesai. Jika registrasi gagal, cek alamat koordinator dan pastikan token berasal dari verifikasi OTP yang berhasil.

6. Hentikan worker saat ingin berhenti menyumbangkan CPU.

   ```bash
   docker compose down
   ```

## Integrasi dengan koordinator

Worker mengirim token sebagai `Authorization: Bearer <token>` dan mendapat identitas worker dari `/api/register`. Setelah itu worker mengambil tugas melalui `/api/tasks/claim`, memperpanjang waktu pengerjaan melalui `/api/heartbeat`, dan mengirim hasil ke `/api/tasks/submit`. Beban kerja yang tersedia adalah Monte Carlo π dan Mandelbrot.

Kontainer berjalan sebagai pengguna non-root dengan filesystem read-only serta batas bawaan 1 CPU, 512 MB memori, dan 64 proses. Worker hanya memerlukan koneksi keluar ke koordinator.

## Untuk developer relawan (jobdesk)

Repo ini adalah **repo B** HPC Cloud Service: kode yang dikembangkan relawan lewat jobdesk.

1. Jobdesk di-assign otomatis oleh sistem (FIFO) saat compute node Anda online. Lihat jobdesk dan
   perintah git-nya di dashboard relawan.
2. Kerjakan di branch jobdesk Anda, bukan di `main`:

   ```bash
   git fetch origin
   git switch task/<id>-<judul>
   # ubah kode, lalu
   python3 -m unittest discover -s tests -t .
   git add -A && git commit -m "..." && git push
   ```

3. Setiap push otomatis di-build dan dites terdistribusi di compute node relawan (CI). Hasilnya muncul
   di dashboard dan sebagai centang/silang di commit GitHub.
4. Setelah CI lulus, tekan **AJUKAN REVIEW** di dashboard. Sistem membuka Pull Request; admin meninjau
   lalu menyetujui (PR di-merge ke `main`) atau meminta revisi.

Pakai email akun GitHub Anda untuk commit (`git config user.email`), karena sistem memeriksa bahwa
commit di branch jobdesk berasal dari pemilik jobdesk itu.

### File CI

- `hpc.json`: perintah build (`python3 -m py_compile worker.py`) dan test. Setiap file
  `tests/test_*.py` menjadi satu tugas test yang dijalankan compute node secara paralel.
- `tests/`: unit test. Tambahkan test baru sebagai file `tests/test_<nama>.py`. Test harus
  deterministik (tanpa jaringan atau waktu acak), karena tiap tugas dijalankan 2 compute node dan
  hasilnya harus sama.

