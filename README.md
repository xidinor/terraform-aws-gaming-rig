# Terraform AWS Gaming Rig

AWS 上に Windows Server 2025 ベースのゲーミング用 EC2 Spot Instance と関連ネットワークを作成する Terraform root module です。

## 前提条件

- Terraform 1.6.0 以上
- 対象 AWS アカウントを操作できる AWS CloudShell
- AWS Provider 5.x、TLS Provider 4.x、Local Provider 2.x（`terraform init` で取得）

## リージョン

デフォルト値として東京リージョン (ap-northeast-1) が選ばれます。

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

## Spot インスタンス

このスクリプトで作成される EC2 インスタンスは価格調整なしの Spot インスタンスです。このため、最大価格は [AWS の仕様](https://aws.amazon.com/blogs/compute/new-amazon-ec2-spot-pricing/)に従ってオンデマンド価格になります。

Spot の空き容量によっては作成できない場合があります。下記の補助スクリプトは、新規作成時の容量不足に限り、`azs` の順（標準では 1a → 1c）で配置を試します。

希望のインスタンスタイプでスポットインスタンスを作成する空きがあるかどうかは [Amazon EC2 スポットインスタンス](https://aws.amazon.com/jp/ec2/spot/instance-advisor/) を確認ください。

インスタンスタイプのデフォルト値は `g5.2xlarge` (8 vCPU, 32GiB RAM, NVIDIA A10G ※RTX3090相当) です。

## 作成・停止・再開・破棄

CloudShell の Python 3 と Terraform を使用し、このリポジトリのディレクトリで実行します。AWS アカウントとリージョンを確認してから使用してください。

```bash
terraform init
python3 apply_with_az_fallback.py
```

通常の `terraform apply` に自動再試行が追加されるわけではありません。作成時は上記スクリプトを実行してください。各 AZ の plan を表示し、`yes` の入力後にその plan を適用します。1a が容量不足なら 1c の plan を作り、再度確認します。`-var` と `-var-file` は指定できますが、保存済み plan、`-target`、`-replace`、`-destroy`、`-auto-approve` は受け付けません。

スクリプトは `aws_instance.app` が state にない新規作成に限り、EC2 の `InsufficientInstanceCapacity` エラーだけを再試行します。権限・クォータ・通信エラー、他リソースのエラー、削除・置換を含む plan、途中までインスタンスが作成された場合には停止します。全 AZ で失敗した場合、ネットワークや鍵など作成済みのリソースは state に残り、次回に再利用します。通信エラーや中断後は AWS コンソールと state を確認してから再実行してください。

選択した AZ は `zz-gaming-placement.auto.tfvars.json`（Git 管理対象外）に保存します。既存インスタンスがある場合は state の AZ を維持します。`instance_az` はスクリプト用の入力で、手動変更するとインスタンスの置換につながります。スクリプトは AWS Provider の `max_retries` を実行中だけ2にして、容量不足が判明するまでの長い API 再試行を抑えます。これは他の AWS API の再試行にも適用されます。通常の Terraform 実行では Provider の標準値を使用します。

利用期間中は EC2 コンソールから同じインスタンスを停止・再開できます。再開には元の AZ の Spot 容量が必要で、別 AZ への移動はしません。停止中も EBS などの料金は発生します。

利用終了後は、対象と削除内容を確認して利用者自身で破棄します。

```bash
terraform destroy
```

破棄後、次回も `python3 apply_with_az_fallback.py` を実行します。state にインスタンスがなくなっているため、保存済みの AZ に関係なく `azs` の先頭から試し直します。Terraform の state と選択ファイルは利用期間中保持してください。スクリプトは `default` workspace 専用です。同じディレクトリでスクリプトや Terraform を並行実行しないでください。`TF_CLI_ARGS*` は未設定にしてください。

エージェントの検証ではこのスクリプトによる AWS 操作は実行しません。テストは Terraform をモックして実施します。

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
