# Inputs


#Série temporal----

selecionar_doenca_serie_temporal <- pickerInput('doenca_st', "Selecione a doença de interesse",
                                                choices = c("Dengue", "Doença de Chagas",
                                                            "Esquistossomose", "Envenenamento por picada de cobra",
                                                            "Febre chikungunya", "Hanseníase",
                                                            "Leishmaniose visceral", "Leishmaniose tegumentar americana",
                                                            "Raiva humana"),
                                                multiple = FALSE)

selecionar_uf_st<- pickerInput(
  "uf_st", 
  "Selecione a UF:", 
  choices = c(
    'Brasil',  # Adiciona a opção 'Todos'
    'Acre', 'Alagoas', 'Amapá', 'Amazonas', 'Bahia', 'Ceará', 'Distrito Federal', 
    'Espírito Santo', 'Goiás', 'Maranhão', 'Mato Grosso', 'Mato Grosso do Sul', 
    'Minas Gerais', 'Pará', 'Paraíba', 'Paraná', 'Pernambuco', 'Piauí', 
    'Rio de Janeiro', 'Rio Grande do Norte', 'Rio Grande do Sul', 'Rondônia', 
    'Roraima', 'Santa Catarina', 'São Paulo', 'Sergipe', 'Tocantins'
  ), multiple = TRUE
)


selecionar_sexo <- selecionar_sexo <- pickerInput("sexo", "Selecione o sexo:", choices = c('Masculino', 'Feminino', 'Ambos'), multiple = TRUE)

selecionar_idade <- pickerInput("faixa_etaria", "Selecione a faixa etária:", 
                                choices = c('Todos',
                                            '0-4',
                                            '5-9',
                                            '10-14',
                                            '15-19',
                                            '20-24',
                                            '25-29',
                                            '30-34',
                                            '35-39',
                                            '40-44',
                                            '45-49',
                                            '50-54',
                                            '55-59',
                                            '60-64',
                                            '65-69',
                                            '70-74',
                                            '75-79',
                                            '80-84',
                                            '85-89',
                                            '90 ou mais'),
                                multiple= TRUE)

botao_st <- actionButton("update_st", "Atualizar plot")



#Pirâmide etária----

selecionar_doenca_piramide_etaria <- pickerInput('doenca_pe', "Selecione a doença de interesse",
                                                 choices = c("Dengue", "Doença de Chagas",
                                                             "Esquistossomose", "Envenenamento por picada de cobra",
                                                             "Febre chikungunya", "Hanseníase",
                                                             "Leishmaniose visceral", "Leishmaniose tegumentar americana",
                                                             "Raiva humana"))

selecionar_uf_pe <- pickerInput(
  "uf_pe", 
  "Selecione a UF:", 
  choices = c(
    'Brasil',  # Adiciona a opção 'Todos'
    'Acre', 'Alagoas', 'Amapá', 'Amazonas', 'Bahia', 'Ceará', 'Distrito Federal', 
    'Espírito Santo', 'Goiás', 'Maranhão', 'Mato Grosso', 'Mato Grosso do Sul', 
    'Minas Gerais', 'Pará', 'Paraíba', 'Paraná', 'Pernambuco', 'Piauí', 
    'Rio de Janeiro', 'Rio Grande do Norte', 'Rio Grande do Sul', 'Rondônia', 
    'Roraima', 'Santa Catarina', 'São Paulo', 'Sergipe', 'Tocantins'
  ), multiple = TRUE
)


selecionar_ano_pe <- pickerInput('ano_pe', 'Selecione o ano',
                              choices = c(2007:2024))

botao_pe <- actionButton("update_pe", "Atualizar plot")





#Estatística descritiva----
selecionar_doenca_estatistica_descritiva <- pickerInput('doenca_ed', "Selecione a doença de interesse",
                                                        choices = c("Dengue", "Doença de Chagas",
                                                                    "Esquistossomose", "Envenenamento por picada de cobra",
                                                                    "Febre chikungunya", "Hanseníase",
                                                                    "Leishmaniose visceral", "Leishmaniose tegumentar americana",
                                                                    "Raiva humana"))

selecionar_uf_ed <- pickerInput(
  "uf_ed", 
  "Selecione a UF:", 
  choices = c(
    'Acre', 'Alagoas', 'Amapá', 'Amazonas', 'Bahia', 'Ceará', 'Distrito Federal', 
    'Espírito Santo', 'Goiás', 'Maranhão', 'Mato Grosso', 'Mato Grosso do Sul', 
    'Minas Gerais', 'Pará', 'Paraíba', 'Paraná', 'Pernambuco', 'Piauí', 
    'Rio de Janeiro', 'Rio Grande do Norte', 'Rio Grande do Sul', 'Rondônia', 
    'Roraima', 'Santa Catarina', 'São Paulo', 'Sergipe', 'Tocantins'
  ), multiple = FALSE
)

botao_ed <- actionButton("update_ed", "Atualizar plot")



#Mapas----
selecionar_doenca_map <- pickerInput('doenca_map', "Selecione a doença de interesse",
                                                choices = c("Dengue", "Doença de Chagas",
                                                            "Esquistossomose", "Envenenamento por picada de cobra",
                                                            "Febre chikungunya", "Hanseníase",
                                                            "Leishmaniose visceral", "Leishmaniose tegumentar americana",
                                                            "Raiva humana"),
                                                multiple = FALSE)

selecionar_ano_map <- pickerInput('ano_map', 'Selecione o ano',
                                 choices = c(2007:2024))
tipo_mapa <-  radioButtons('tipo_mapa', 'Selecione o tipo de mapa', choices = c("Casos Absolutos", "Incidência"))
botao_map <- actionButton("update_map", "Atualizar plot")


#Barchart race----
selecionar_doenca_br <- pickerInput('doenca_br', "Selecione a doença de interesse",
                                     choices = c("Dengue", "Doença de Chagas",
                                                 "Esquistossomose", "Envenenamento por picada de cobra",
                                                 "Febre chikungunya", "Hanseníase",
                                                 "Leishmaniose visceral", "Leishmaniose tegumentar americana",
                                                 "Raiva humana"),
                                     multiple = FALSE)
selecionar_doenca_animacao_barras <- pickerInput('doenca_ba', "Selecione a doença de interesse",
                                                 choices = c("Dengue", "Doença de Chagas",
                                                             "Esquistossomose", "Envenenamento por picada de cobra",
                                                             "Febre chikungunya", "Hanseníase",
                                                             "Leishmaniose visceral", "Leishmaniose tegumentar americana",
                                                             "Raiva humana"))
botao_br <- actionButton("update_br", "Atualizar plot")
