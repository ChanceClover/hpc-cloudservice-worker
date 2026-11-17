#!/usr/bin/env bash
# Pintasan worker relawan HPC Cloud Service. Jalankan dari folder repo ini: ./hpc.sh <perintah>
#
# Alur pertama kali (Ubuntu WSL2 + Docker Desktop):
#   1. Register di website portal, verifikasi OTP -> dapat token worker (hpc_w_...).
#   2. ./hpc.sh setup <COORDINATOR_URL> <WORKER_TOKEN>   (perintah lengkap ada di dashboard)
#   3. ./hpc.sh up      lalu   ./hpc.sh logs
set -e
cd "$(dirname "$0")"

PROJECT=hpc-relawan
COMPOSE="docker compose --env-file .env -p $PROJECT -f docker-compose.yml"

load_env() {
  [ -f .env ] || return 0
  set -a; . ./.env; set +a
}

# Tulis / ganti satu baris KEY="nilai" di .env
set_env() {
  local key="$1" val="$2" tmp
  tmp=$(mktemp)
  [ -f .env ] && grep -v "^${key}=" .env > "$tmp" || true
  printf '%s="%s"\n' "$key" "$val" >> "$tmp"
  mv "$tmp" .env
  chmod 600 .env
}

# Dari WSL, host.docker.internal belum tentu terbaca; untuk cek token pakai localhost.
host_url() {
  echo "${1/host.docker.internal/localhost}"
}

check_token() {   # check_token <url> <token>  -> cetak nama worker bila sah
  local out
  out=$(curl -s --max-time 15 "$(host_url "$1")/api/auth/me" -H "Authorization: Bearer $2") || {
    echo "  (koordinator $1 tidak dapat dihubungi dari laptop ini)"; return 2; }
  if echo "$out" | grep -q '"type": *"individual"'; then
    echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("  Token sah: %s (@%s)" % (d["worker_name"], d["github_username"]))' 2>/dev/null \
      || echo "  Token sah."
    return 0
  fi
  echo "  Token DITOLAK koordinator: $out"
  return 1
}

need_env() {
  load_env
  if [ -z "${COORDINATOR_URL:-}" ] || [ -z "${WORKER_TOKEN:-}" ]; then
    echo "Belum ada COORDINATOR_URL / WORKER_TOKEN di .env. Jalankan dulu:"
    echo "  ./hpc.sh setup <COORDINATOR_URL> <WORKER_TOKEN>    (salin dari dashboard relawan)"
    exit 1
  fi
}

need_docker() {
  command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 || {
    echo "Docker belum berjalan. Nyalakan Docker Desktop (Settings > Resources > WSL Integration: aktifkan Ubuntu), lalu ulangi."
    exit 1
  }
}

case "${1:-help}" in
  setup|login|worker-login)
    # ./hpc.sh setup [COORDINATOR_URL] [WORKER_TOKEN] [WORKER_NAME]
    load_env
    URL="${2:-}"; TOKEN="${3:-}"; NAME="${4:-${WORKER_NAME:-}}"
    if [ -z "$URL" ]; then
      read -r -p "COORDINATOR_URL [${COORDINATOR_URL:-https://xxx.trycloudflare.com}]: " URL
      URL="${URL:-${COORDINATOR_URL:-}}"
    fi
    if [ -z "$TOKEN" ]; then
      read -r -s -p "WORKER_TOKEN (hpc_w_..., dari dashboard; tidak tampil saat diketik): " TOKEN; echo
    fi
    URL="${URL%/}"
    [ -n "$URL" ] || { echo "COORDINATOR_URL wajib diisi."; exit 1; }
    case "$TOKEN" in
      hpc_w_*) ;;
      *) echo "Token worker harus diawali 'hpc_w_'. Lihat kartu 'Token Worker untuk CLI' di dashboard."; exit 1 ;;
    esac
    [ -n "$NAME" ] || NAME="laptop-$(hostname | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9-' | cut -c1-20)"
    echo "Memeriksa token ke $URL ..."
    set +e; check_token "$URL" "$TOKEN"; RC=$?; set -e
    [ "$RC" = 1 ] && exit 1
    set_env COORDINATOR_URL "$URL"
    set_env WORKER_TOKEN "$TOKEN"
    set_env WORKER_NAME "$NAME"
    grep -q '^WORKER_CPUS=' .env || set_env WORKER_CPUS 1
    grep -q '^WORKER_MEMORY_MB=' .env || set_env WORKER_MEMORY_MB 512
    echo "Tersimpan di .env (hanya di laptop ini, tidak ikut git). Berikutnya: ./hpc.sh up"
    ;;

  up|worker-up)
    need_env; need_docker
    $COMPOSE up -d --build --scale worker="${2:-1}"
    $COMPOSE ps
    echo "Worker berjalan. Pantau: ./hpc.sh logs   Matikan: ./hpc.sh down"
    ;;

  down|worker-down)
    load_env
    $COMPOSE down
    ;;

  logs|worker-logs)
    load_env
    $COMPOSE logs -f --tail 50
    ;;

  status|worker-status)
    load_env
    echo "COORDINATOR_URL : ${COORDINATOR_URL:-(belum diisi)}"
    echo "WORKER_NAME     : ${WORKER_NAME:-(belum diisi)}"
    if [ -n "${WORKER_TOKEN:-}" ]; then
      echo "WORKER_TOKEN    : ${WORKER_TOKEN:0:10}... (tersimpan)"
      [ -n "${COORDINATOR_URL:-}" ] && { check_token "$COORDINATOR_URL" "$WORKER_TOKEN" || true; }
    else
      echo "WORKER_TOKEN    : (belum diisi, jalankan ./hpc.sh setup)"
    fi
    echo
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
      $COMPOSE ps
    else
      echo "Docker belum berjalan."
    fi
    ;;

  update)
    # Ambil versi terbaru worker dari main, lalu bangun ulang kontainer yang sedang jalan
    git pull --ff-only
    need_env; need_docker
    N=$($COMPOSE ps -q worker 2>/dev/null | wc -l)
    $COMPOSE up -d --build --scale worker="$([ "$N" -gt 0 ] && echo "$N" || echo 1)"
    ;;

  test)
    # Unit test yang sama dengan CI terdistribusi (hpc.json)
    python3 -m unittest discover -s tests -t . -v
    ;;

  help|-h|--help|*)
    cat << 'USAGE'
Pemakaian: ./hpc.sh <perintah>

Pertama kali:
  setup [URL] [TOKEN] [NAMA]   simpan alamat koordinator + token worker ke .env (token dicek dulu).
                               Tanpa argumen akan ditanya. Salin perintah lengkapnya dari dashboard.
Sehari-hari:
  up [n]       nyalakan n worker sandbox di Docker (bawaan 1)
  logs         lihat tugas yang dikerjakan worker (Ctrl+C untuk keluar)
  status       cek .env, keabsahan token, dan kontainer yang berjalan
  down         matikan worker
  update       git pull versi terbaru lalu bangun ulang worker
Developer (jobdesk):
  test         jalankan unit test lokal (sama dengan CI)

Nama lama juga bisa dipakai: worker-up, worker-logs, worker-status, worker-down, worker-login (= setup).
Login WEBSITE memakai email + password; token worker hanya untuk perintah di atas.
USAGE
    ;;
esac
