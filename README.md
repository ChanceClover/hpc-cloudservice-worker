# HPC Cloud Service Worker

Worker relawan menggunakan CPU perangkat Anda untuk menjalankan tugas dari koordinator HPC Cloud Service. Portal di repositori [hpc-cloudservice](https://github.com/ChanceClover/hpc-cloudservice) menangani registrasi relawan dan penerbitan token.

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
