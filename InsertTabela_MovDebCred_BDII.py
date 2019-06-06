import random

#------------------
# função do digito

def verificar_digito(conta):
    mascara = '27654327654'
    soma = 0
    for i in range(11):
        soma += int(mascara[i]) * int(conta[i])
    resto = soma % 11
    digito = 11-resto
    if (digito == 10):
        digito = 0
    elif (digito == 11):
        digito = '&'
    return digito

#--------------
# contas analiticas

vetor = ['11010100000','11010200000','11020100000','11020200000','11020300000','11020400000',
         '11030100000','11030200000','11030300000','12010000000','12020000000','12030000000']

#---------------
# loop maravilha

for i in range(40):
    conta = random.randrange(0,12)      # escolhe uma conta do vetor
    dia = random.randrange(1, 29)       # está ate 28 para não dar erro em fevereiro
    mes = random.randrange(1, 5)        # movimentações de janeiro a abril
    ano = random.randrange(2019, 2020)  # configurado pra 2019
    debcred = 'DC'                      # no print ele escolhe entre Debito ou Credito
    valor = random.randrange(20, 401)
    print("INSERT INTO MovDebCred (numConta, dig, data, debCred, valor) VALUES ({}, '{}', '{}-{}-{}', '{}', {});"
          .format(vetor[conta],verificar_digito(vetor[conta]),dia,mes,ano,debcred[random.randrange(0,2)],valor))
