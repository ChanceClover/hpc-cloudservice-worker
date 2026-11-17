# HPC Cloud Service Worker

Worker relawan menggunakan CPU perangkat Anda untuk menjalankan tugas dari koordinator HPC Cloud Service. Portal di repositori [hpc-cloudservice](https://github.com/NoelianGH/hpc-cloudservice) menangani registrasi relawan dan penerbitan token.

## Menjalankan worker (compute node)

Repo ini berisi worker relawan sekaligus kode yang Anda kerjakan lewat jobdesk. Worker dijalankan dari
folder repo ini dengan `./hpc.sh`. Repo platform ([hpc-cloudservice](https://github.com/NoelianGH/hpc-cloudservice))
tidak perlu di-clone relawan.

Ada dua kredensial dengan kegunaan berbeda:

| Kredensial | Dipakai untuk | Disimpan di |
| --- | --- | --- |
| Email + password | Login website (dashboard, jobdesk, sertifikat) | Browser (sesi 7 hari) |
| Token worker `hpc_w_...` | Worker di terminal: ambil tugas, kirim hasil | File `.env` repo ini |

1. Siapkan Ubuntu WSL2 dan Docker Desktop (Settings > Resources > WSL Integration: aktifkan Ubuntu).
2. Register di website portal, lalu verifikasi OTP. Setelah itu dashboard menampilkan perintah setup
   yang sudah berisi alamat koordinator dan token worker Anda (kartu "Jalankan Worker Anda").
3. Clone repo ini dan jalankan setup (token diperiksa ke koordinator sebelum disimpan):

   ```bash
   git clone https://github.com/ChanceClover/hpc-cloudservice-worker.git ~/hpc-cloudservice-worker
   cd ~/hpc-cloudservice-worker && chmod +x hpc.sh
   ./hpc.sh setup <COORDINATOR_URL> <WORKER_TOKEN>
   ```

   Tanpa argumen, `./hpc.sh setup` akan menanyakan alamat dan token. Satu laptop dengan head node?
   Pakai `http://host.docker.internal:8000` sebagai alamat.

4. Nyalakan worker dan pantau tugasnya:

   ```bash
   ./hpc.sh up        # 1 worker sandbox (1 CPU, 512 MB); ./hpc.sh up 2 untuk 2 worker
   ./hpc.sh logs      # Ctrl+C untuk keluar dari log, worker tetap jalan
   ./hpc.sh status    # cek token + kontainer
   ./hpc.sh down      # berhenti menyumbang CPU
   ```

Lupa token, atau token dicabut admin? Buka dashboard, kartu "Token Worker untuk CLI": tampilkan atau buat
token baru, lalu ulangi `./hpc.sh setup` dan `./hpc.sh up`.

## Integrasi dengan koordinator

Worker mengirim token sebagai `Authorization: Bearer <token>` dan mendapat identitas worker dari `/api/register`.
Setelah itu worker mengambil tugas melalui `/api/tasks/claim` (FIFO), memperpanjang waktu pengerjaan melalui
`/api/heartbeat`, dan mengirim hasil ke `/api/tasks/submit`. Jenis tugas: Monte Carlo π, Mandelbrot, simulasi
panas 2D multi-tahap (`heat2d`), program dari repo job pada commit SHA tertentu, serta build/test CI
terdistribusi (`ci_build`, `ci_test`) untuk setiap push ke repo ini.

Kontainer berjalan sebagai pengguna non-root dengan filesystem read-only serta batas bawaan 1 CPU, 512 MB
memori, dan 64 proses. Kode yang diminta tugas di-clone ke `/tmp` (RAM, hilang saat kontainer mati). Worker
hanya memerlukan koneksi keluar ke koordinator dan GitHub.

## Untuk developer relawan (jobdesk)

Repo ini adalah **repo B** HPC Cloud Service: kode yang dikembangkan relawan lewat jobdesk.

1. Jobdesk di-assign otomatis oleh sistem (FIFO) saat compute node Anda online. Lihat jobdesk dan
   perintah git-nya di dashboard relawan.
2. Kerjakan di branch jobdesk Anda, bukan di `main`:

   ```bash
   git fetch origin
   git switch task/<id>-<judul>
   # ubah kode, lalu
   ./hpc.sh test
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

