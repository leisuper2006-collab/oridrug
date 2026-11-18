#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
home_dir="${ORIDRUG_HOME:-$script_dir/.oridrug}"
project="${ORIDRUG_PROJECT:-oridrug-personal}"
port="${ORIDRUG_PORT:-8789}"
release_url="https://github.com/leisuper2006-collab/oridrug/releases/download/v0.7.1"

fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ $project =~ ^[a-z0-9][a-z0-9_-]*$ ]] || fail "工作台实例名格式错误。"
[[ $port =~ ^[1-9][0-9]{3,4}$ ]] && (( port >= 1024 && port <= 65535 )) || fail "请使用 1024 至 65535 之间的端口。"
[[ $# == 0 || ( $# == 1 && $1 == --stop ) ]] || fail "使用 bash portable/start.sh 或 bash portable/start.sh --stop。"

instance="$home_dir/$project"
cache="$home_dir/downloads"
config="$instance/instance.env"
mkdir -p -- "$instance" "$cache"
umask 077
command -v docker >/dev/null || fail "请安装 Docker Engine 和 Compose: https://docs.docker.com/engine/install/"
command -v flock >/dev/null || fail "请安装 util-linux 的 flock 命令。"
exec 9>"$instance/launch.lock"
flock -n 9 || fail "已有同一工作台的启动程序正在运行。"
engine=""
for ((attempt=0; attempt<60; attempt++)); do
    if engine=$(docker version --format '{{.Server.Os}}/{{.Server.Arch}}' 2>/dev/null); then break; fi
    sleep 2
done
[[ $engine == linux/amd64 ]] || fail "请启动 Linux x86-64 Docker 引擎，然后重新运行。"
docker compose version --short >/dev/null

export ORIDRUG_PORT="$port" ORIDRUG_ALLOWED_HOSTS="127.0.0.1,localhost,api" ORIDRUG_HTTPS=0 ORIDRUG_FORWARDED_HOST="" ORIDRUG_FORWARD_PROTO=http
if [[ "${CODESPACES:-}" == true ]]; then
    domain="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
    [[ ${CODESPACE_NAME:-} =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ && $domain =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]] || fail "Codespaces 转发地址无效。"
    export ORIDRUG_FORWARDED_HOST="$CODESPACE_NAME-$port.$domain"
    export ORIDRUG_ALLOWED_HOSTS="$ORIDRUG_ALLOWED_HOSTS,$ORIDRUG_FORWARDED_HOST" ORIDRUG_HTTPS=1 ORIDRUG_FORWARD_PROTO=https
fi
compose=(docker compose --project-name "$project" --env-file "$config" --file "$script_dir/compose.yaml")
if [[ ${1:-} == --stop ]]; then
    if [[ -f $config ]]; then "${compose[@]}" stop; fi
    printf '工作台已停止，项目与账号已保留。\n'
    exit 0
fi

while read -r owner; do
    [[ -z $owner || $owner == "$project-web-1" ]] || fail "端口 $port 已由其他容器使用。可用 ORIDRUG_PORT=8790 指定空闲端口。"
done < <(docker ps --filter "publish=$port" --format '{{.Names}}')

image_layers() {
    local value
    value=$(docker image inspect --format '{{range .RootFS.Layers}}{{.}} {{end}}' "$1" 2>/dev/null) || { printf ''; return 0; }
    value="${value% }"
    printf '%s' "${value// /,}"
}

verify_hash() {
    local filename="$1" expected="$2" actual
    [[ -f $filename ]] || return 1
    actual=$(sha256sum -- "$filename")
    [[ ${actual%% *} == "$expected" ]]
}

manifest="$script_dir/images.lock"
[[ -f $manifest && $(wc -l <"$manifest") -eq 3 ]] || fail "请使用包含 images.lock 的完整启动包。"
mapfile -t assets < <(cut -f1 "$manifest" | sort -u)
for file in "${assets[@]}"; do
    import=false
    expected_hash=""
    while IFS=$'\t' read -r name hash tag expected_layers; do
        [[ $name == "$file" ]] || continue
        expected_hash="$hash"
        actual=$(image_layers "$tag")
        if [[ -z $actual ]]; then import=true
        elif [[ $actual != "$expected_layers" ]]; then fail "Docker 中已存在内容不同的同名镜像 $tag，请为原镜像另存标签后重试。"
        fi
    done <"$manifest"
    [[ $import == true ]] || continue
    archive="${ORIDRUG_IMAGES_DIR:-$cache}/$file"
    if ! verify_hash "$archive" "$expected_hash"; then
        [[ -z ${ORIDRUG_IMAGES_DIR:-} ]] || fail "离线文件缺失或未通过校验：$file"
        printf '正在从 GitHub 下载 %s\n' "$file"
        partial=$(mktemp "$cache/.image.XXXXXXXX")
        trap 'rm -f -- "$partial"' EXIT
        curl --fail --show-error --location --retry 3 --connect-timeout 20 --output "$partial" "$release_url/$file"
        verify_hash "$partial" "$expected_hash" || fail "文件校验失败，请重新下载：$file"
        mv -f -- "$partial" "$archive"
        trap - EXIT
    fi
    docker image load --input "$archive"
    while IFS=$'\t' read -r name hash tag expected_layers; do
        [[ $name == "$file" ]] || continue
        [[ $(image_layers "$tag") == "$expected_layers" ]] || fail "导入的镜像与清单不符：$tag"
    done <"$manifest"
done

if [[ ! -f $config ]]; then
    db_volume=$(docker volume ls --quiet --filter "label=com.docker.compose.project=$project" --filter 'label=com.docker.compose.volume=database')
    [[ -z $db_volume ]] || fail "检测到已有工作台数据库。请恢复原有 .oridrug 配置后启动。"
    command -v openssl >/dev/null || fail "请安装 openssl 后重新启动。"
    temporary_config=$(mktemp "$instance/.config.XXXXXXXX")
    trap 'rm -f -- "$temporary_config"' EXIT
    database_key=$(openssl rand -hex 36)
    django_key=$(openssl rand -hex 48)
    encryption_key=$(openssl rand -base64 32 | tr '+/' '-_')
    printf 'ORIDRUG_DATABASE_KEY=%s\nORIDRUG_DJANGO_KEY=%s\nORIDRUG_ENCRYPTION_KEY=%s\n' "$database_key" "$django_key" "$encryption_key" >"$temporary_config"
    mv -- "$temporary_config" "$config"
    trap - EXIT
fi

printf '正在准备数据库并启动研究工作台…\n'
"${compose[@]}" up --detach
base_url="http://127.0.0.1:$port"
for ((attempt=0; attempt<90; attempt++)); do
    if curl --noproxy '*' --silent --fail --max-time 3 "$base_url/api/health/" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"ok"'; then
        address="$base_url"
        if [[ -n $ORIDRUG_FORWARDED_HOST ]]; then address="https://$ORIDRUG_FORWARDED_HOST"; fi
        printf '工作台已就绪。打开 %s 并点「注册」，就能建立自己的项目。\n' "$address"
        exit 0
    fi
    sleep 2
done
fail "工作台仍在初始化。请再次运行启动器查看服务状态。"
