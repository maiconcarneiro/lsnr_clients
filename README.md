# lsnr_clients
Script para analisar Log do Listener e gerar lista de IPs que conectaram no banco de dados Oracle

1) Acesso o servidor de banco de dados com o usuário que é dono do Listener (exemplo: grid)

2) Crie o script lsnr_clients.sh no servidor de banco de dados e cole o conteúdo do script.
 Se tiver acesso a internet, pode usar o comando abaixo para baixar o script:
 
   $ wget "https://raw.githubusercontent.com/maiconcarneiro/lsnr_clients/main/lsnr_clients.sh"; chmod +x lsnr_clients.sh

3) Execute o script no shell

  $ sh lsnr_clients.sh



Parâmetros opcionais:

  $ sh lsnr_clients.sh intervalo gera_contagem servico listener 



Exemplo com todos os parâmetros:

  $ sh lsnr_clients.sh 30 s XPTOPRD LISTENERPROD



Onde:
30 --> Intervalo de 30 dias (pega todos os arquivos de log com data de alteração nos últimos 30 dias)
 
s --> "Gera Contagem" = Sim   (apresenta um resumo com a quantidade de conexões originada a partir de cada IP)
 
XPTOPRD --> Considera somente conexõs para o SERVICE_NAME "XPTOPRD"
 
LISTENERPROD --> Analisa log do Listener "LISTENERPROD" (requerido somente quando quiser analisar um Listener diferente do primeiro que é encontrado automaticamente pelo script)
