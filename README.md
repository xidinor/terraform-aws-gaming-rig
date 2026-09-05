# Terraform AWS Gaming Rig

AWS 上に Windows Server 2025 ベースのゲーミング用 EC2 Spot Instance と関連ネットワークを作成する Terraform root module です。

## 前提条件

- Terraform 1.6.0 以上
- 対象 AWS アカウントを操作できる AWS CloudShell
- AWS Provider 5.x、TLS Provider 4.x、Local Provider 2.x（`terraform init` で取得）

## AMI の選択

`instance_ami` を省略すると、AWS Provider に設定した `region` で次の Systems Manager 公開パラメータを参照し、Windows Server 2025 English Full Base の AMI ID を取得します。

```text
/aws/service/ami-windows-latest/Windows_Server-2025-English-Full-Base
```

特定の AMI ID を使う場合は、HCL のダブルクォート文字列として指定します。この場合、上記 SSM Parameter は参照しません。

```hcl
instance_ami = "ami-0123456789abcdef0"
```

別の公開パラメータを利用する場合は、`ssm_ami_parameter_name` を上書きできます。

## EC2 Key Pair

既存の EC2 Key Pair を使う場合は、その名前を指定します。

```hcl
key_name = "existing-key-pair"
```

`key_name` を省略して `terraform apply` を実行すると、Terraform が `deployer-key` という EC2 Key Pair を生成し、秘密鍵を Terraform 実行ディレクトリの `deployer-key.pem` にパーミッション `0600` で保存します。保存先は次の output でも確認できます。

```bash
terraform output -raw generated_private_key_file
```

AWS CloudShellでは、画面の **Actions** から **Download file** を選び、上記コマンドで確認したパスを指定してダウンロードできます。

`deployer-key.pem` はGitの管理対象外です。

## 初期化と静的検証

```bash
terraform init -backend=false -input=false
terraform fmt -check -diff -recursive
terraform validate
```

`terraform plan` はAWS APIを参照します。対象アカウント、リージョン、入力値を確認できる場合に限り実行してください。`terraform apply` と `terraform destroy` は、リポジトリのエージェントによる検証では実行しません。
