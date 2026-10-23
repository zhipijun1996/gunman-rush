for apt_source in /etc/apt/sources.list /etc/apt/sources.list.d/ubuntu.sources /etc/apt/apt-mirrors.txt; do
  if [ -f "$apt_source" ]; then sudo sed -i -E ':azure_mirror; s#(^|[[:space:]])https?://azure\.archive\.ubuntu\.com/ubuntu([/[:space:]]|$)#\1https://archive.ubuntu.com/ubuntu\2#g; t azure_mirror' "$apt_source"; fi
done
