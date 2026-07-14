# Exportar Power BI para PDF

O script `Export-PowerBIToPdf.ps1` abre um arquivo `.pbix` no Power BI Desktop,
automatiza **Arquivo > Exportar > Exportar para PDF** e copia o PDF gerado para
o destino escolhido.

## Requisitos

- Windows 10 ou 11;
- Power BI Desktop instalado;
- PowerShell 5.1 ou 7;
- uma sessao interativa com a tela desbloqueada.

O Power BI Desktop nao possui uma linha de comando oficial para exportar um
arquivo PBIX local para PDF. Por isso, o script usa a automacao de interface do
Windows. Nao execute o script como servico, tarefa em segundo plano ou com a
sessao bloqueada.

Normalmente, o Desktop cria o PDF em `%TEMP%\Power BI Desktop` e o abre no
visualizador padrao. O script detecta esse arquivo temporario e o copia para o
destino. Ele tambem trata a janela **Salvar como**, caso a versao instalada a
utilize.

## Uso

Abra o PowerShell e execute:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Export-PowerBIToPdf.ps1 -InputPath "C:\Relatorios\Vendas.pbix"
```

Sem `-OutputPath`, o PDF e salvo ao lado do PBIX, com o mesmo nome.

Para escolher o destino:

```powershell
.\Export-PowerBIToPdf.ps1 `
  -InputPath "C:\Relatorios\Vendas.pbix" `
  -OutputPath "C:\Exports\Vendas.pdf"
```

Se o PDF ja existir, use `-Force` para substitui-lo:

```powershell
.\Export-PowerBIToPdf.ps1 `
  -InputPath "C:\Relatorios\Vendas.pbix" `
  -OutputPath "C:\Exports\Vendas.pdf" `
  -Force
```

Opcoes uteis:

- `-LoadDelaySeconds 60`: aumenta a espera para relatorios grandes;
- `-TimeoutSeconds 600`: aumenta o limite de cada etapa;
- `-PowerBIExecutable "C:\...\PBIDesktop.exe"`: informa o executavel quando ele
  nao e localizado automaticamente;
- `-ClosePowerBI`: fecha a janela depois da exportacao.

O script reconhece os menus do Power BI e as janelas do Windows em portugues e
ingles.

## Relatorios publicados

Para execucao sem interface (servidor, pipeline ou agendamento), publique o
relatorio no Power BI Service e use a API REST `ExportToFile`. Essa alternativa
exige uma capacidade compativel e autenticacao no Microsoft Entra ID; ela nao
abre arquivos PBIX locais.
