library(RMySQL)
# Estabelecendo conexão com o MySQL
mysqlconnection <- dbConnect(RMySQL::MySQL(),
                             dbname = '', #nome do banco de dados MySQL
                             host = '', #endereõ host, por padrão é localhost em servidores locais
                             port = 3306,  #Porta padrão do MySQL
                             user = '', #usuario que ira acessar o servidor
                             password = '') #senha do usuário
dbListTables(mysqlconnection)
