# Encontra os diretórios contendo htaccessORIGINAL e move seu conteúdo para /var/www/html
for dir in $(find /var/www/html -type f -name "htaccessORIGINAL" -exec dirname {} \;); do
  if [ "$dir" != "/var/www/html" ]; then
    cp -pRf "$dir"/* /var/www/html/ && rm -rf $dir && cp -p /var/www/html/htaccessORIGINAL /var/www/html/.htaccess
  else
    echo "O diretório de origem é o mesmo que o de destino, ignorando: $dir"
  fi
done


