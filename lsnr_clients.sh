#!/bin/bash
# lsnr_clients.sh - v1.4
# Script para analizar Log do Listener e gerar lista de IPs que conectaram no banco de dados Oracle
#
# Instrucoes de uso no Blog do Dibiei
# "https://dibiei.wordpress.com/2022/01/12/gerando-lista-de-ips-que-conectaram-no-banco-de-dados-atraves-do-log-do-listener-script-lsnr_clients-sh/"
#
# Download: wget "https://raw.githubusercontent.com/maiconcarneiro/lsnr_clients/main/lsnr_clients.sh"; chmod +x lsnr_clients.sh
# Exemplo simples..: ./lsnr_clients.sh
# Exemplo full.....: ./lsnr_clients.sh -i 15 -c s - s ORCL -l LISTENER_PRD
#
# Data       | Autor              | Modificacao
# 10/01/2022 | Maicon Carneiro    | Codigo para identificar o diretorio do listener automaticamente
# 12/01/2022 | Maicon Carneiro    | Adicionado suporte a versao 11gR2 com ajuste na chamada do lsnrctl
# 21/03/2022 | Maicon Carneiro    | Corrigido bug que retornava mais de uma linha ao obter o ORACLE_HOME do Listener

periodo="1"
geraContagem="n"
nomeServico=""
nomeListener=""
 
while getopts ":i:c:s:l:" opt; do
  case $opt in
    i) periodo="$OPTARG"
    ;;
    c) geraContagem="s"
    ;;
    s) nomeServico="$OPTARG"
    ;;
    l) nomeListener="$OPTARG"
    ;;
    \?) echo "Parametro invalido -$OPTARG" >&2
    exit 1
    ;;
  esac
 
done
 
dataArquivo=$(date +'%H%M%S')
dirInicial=$(pwd)
 
arquivoConexoes="$dirInicial/lsnrchkip_conn_$dataArquivo.txt"
arquivoListaIP="$dirInicial/lsnrchkip_list_$dataArquivo.txt"
arquivoContagem="$dirInicial/lsnrchkip_cont_$dataArquivo.txt"
arquivoContagemStage="$dirInicial/lsnrchkip_cont_stage_$dataArquivo.txt"
arquivoScriptLsnrctl="$dirInicial/lsnrchkip_lsnrctl_$dataArquivo.sh"
 
LimpaArquivosTemporarios()
{
   rm -f $arquivoConexoes
   rm -f $arquivoListaIP
   rm -f $arquivoContagem
   rm -f $arquivoContagemStage
   rm -f $arquivoScriptLsnrctl
}
 
# Senão for informado, assume primeiro listener encontrado no servidor
if [ -z "$nomeListener" ]; then
 nomeListener=$(ps -ef | grep tnslsnr | egrep -v 'ASM|SCAN|MGM|grep' | awk '{ print $9 }' | head -n1)
fi;
 
# Define propriedades do Listener
linhaListener=$(ps -ef | grep tnslsnr | grep $nomeListener | egrep -v 'ASM|SCAN|MGM|grep' | head -n1 )
ownerListener=$(echo "$linhaListener" | awk '{ print $1 }')
 
if [ -z "$linhaListener" ]; then
 echo "Erro: Listener $nomeListener deve estar online."
 exit 1
fi
 
usuarioAtual=$(whoami)
if [ "$usuarioAtual" != "$ownerListener" ]; then
echo "Erro: O script deve ser executado com o usuario dono do Listener!"
echo "Execute o script com o usuario $ownerListener"
exit 1;
fi
 
pidListener=$(echo "$linhaListener" | awk '{ print $2 }')
ORACLE_HOME=$(strings /proc/$pidListener/environ | grep ORACLE_HOME | grep -v '{' | awk -F "=" '{print $2}')
 
# obtem o diretorio de log do listener (11gR2da problema quando nao usa o current_listener )
echo "$ORACLE_HOME/bin/lsnrctl <<EOF
set current_listener $nomeListener
show log_directory
EOF" > $arquivoScriptLsnrctl
 
chmod +x $arquivoScriptLsnrctl
dirLogListener=$(sh $arquivoScriptLsnrctl | grep log_directory | awk '{ print $6 }' | sed -e "s/alert/trace/g" )
rm -f $arquivoScriptLsnrctl
 
echo "*********************************************************************************"
echo "Servidor..................: $(hostname)"
echo "Data da analise...........: $(date +'%d/%m/%Y %H:%M:%S')"
echo "Utima modificacao do log..: $periodo (dias)"
echo "Nome do Listener..........: $nomeListener"
echo "Dono do Listener..........: $ownerListener"
echo "Binario do Listener.......: $ORACLE_HOME"
echo "Service Name..............: $nomeServico"
echo ""
echo "Arquivos de log analisados:"
 find $dirLogListener -mtime -$periodo | grep -i "$nomeListener" | grep .log | egrep -v '.gz|.zip'
echo ""
echo "*********************************************************************************"
 
cd $dirLogListener
for arquivo in $(find . -mtime -$periodo | grep -i "$nomeListener" | grep .log | egrep -v '.gz|.zip')
do
 grep -H CONNECT_DATA $arquivo | grep -i "$nomeServico" >> $arquivoConexoes
done
cd $dirInicial
 
logMaisAntigo=$(head -1 $arquivoConexoes | awk -F "*" '{ print $1 }')
logMaisRecente=$(tail -1 $arquivoConexoes | awk -F "*" '{ print $1 }')
 
echo "";
echo "================================================================================="
echo "Log mais antigo...: $logMaisAntigo"
echo "Log mais recente..: $logMaisRecente"
echo "================================================================================="
echo ""; echo ""
 
# gera lista de IPs distintos
awk -F "*" '{ print $3 }' $arquivoConexoes | awk -F "=" '{ print $4 }' | awk -F ")" '{ print $1 }' | sort > $arquivoListaIP
 
echo "Lista de IPs identificados:"
echo "-----------------------"
cat $arquivoListaIP | uniq
echo ""
 
if [ "$geraContagem" = "s" ]; then
 
for IP in $(cat $arquivoListaIP | uniq)
do
 QtConexoes=$(grep -wc $IP $arquivoListaIP)
  line='               '
 printf "%s %s $QtConexoes\n" $IP "${line:${#IP}}" >> $arquivoContagemStage
done
 
# ordena o resultado pelo numero de conexoes
sort -k 2n $arquivoContagemStage >> $arquivoContagem
 
echo "Contagem de conexoes por IP:"
echo "==========================="
echo "      HOST        Qtde"
echo "==========================="
 cat $arquivoContagem
echo "==========================="
 
fi
 
LimpaArquivosTemporarios
echo "Analise concluida com sucesso em $(date +'%d/%m/%Y %H:%M:%S')"
echo ""
