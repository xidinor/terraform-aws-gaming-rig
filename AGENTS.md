# AGENTS.md

## 適用範囲

このファイルの指示は、リポジトリ全体に適用する。

このリポジトリは、リポジトリルートを Terraform root module として使用する構成である。現在、主な Terraform 設定は以下のファイルに格納されている。

- `main.tf`
- `variables.tf`
- `outputs.tf`

作業を開始する前に実際のファイル構成を確認すること。`examples/`、`tests/`、子モジュール、CI workflow、README などが存在すると仮定しないこと。

## 開発ベースブランチ

通常の開発では、`develop` をベースブランチとする。

変更を開始する前に、現在のブランチ、ローカルブランチ、remote branch、remote 設定、および working tree の状態を確認すること。

- `develop` が存在する場合、通常は `develop` をベースに作業する。
- ユーザーが別のブランチを明示的に指定した場合は、その指示を優先する。
- `develop` が存在しない場合、ユーザーの明示的な指示なしに作成、reset、push してはならない。
- `develop` が存在しない場合は、確認できたブランチ状態をユーザーへ報告する。
- 作業開始前から存在するユーザーの変更を破棄、上書き、または無断で修正してはならない。
- 明示的な依頼がない限り、force push、rebase、過去コミットの amend など、ブランチ履歴を書き換える操作を行わない。

## 変更範囲

依頼された作業を完了するために必要な変更だけを行うこと。

- unrelated なリファクタリングを行わない。
- スタイル上の理由だけでファイル名やディレクトリ構成を変更しない。
- 変更対象と関係のない Terraform block を再フォーマットしない。
- タスクで必要とされていない Terraform や Provider のバージョンアップを行わない。
- タスクに関係のないツール、CI、Module、Example、Test、ドキュメントを追加しない。
- 依頼された変更に必要でない限り、既存 resource の動作を変更しない。
- 問題を発見しても、依頼範囲外であれば勝手に修正せず、必要に応じて最終回答の残課題として報告する。

## Terraform の互換性

Terraform 設定を変更する前に、`main.tf` にある `required_version` と `required_providers` を確認すること。

既存の Terraform 変数と outputs について、可能な限り後方互換性を維持すること。

特に、以下のルールを守ること。

- 明示的な承認なしに既存 variable を削除または rename しない。
- 明示的な承認なしに既存 output を削除または rename しない。
- 必要性を確認せず、既存 variable の型、default、validation、意味を変更しない。
- 必要性を確認せず、既存 output の型や意味を変更しない。
- Module interface を拡張する場合は、可能な限り既存利用者に影響しない追加的な変更を選ぶ。
- 以前は省略できた入力を、無断で必須入力に変更しない。
- Provider version constraint、Terraform version constraint、resource address、state layout、resource replacement を発生させる変更は、互換性に影響する変更として扱う。
- 破壊的変更が避けられない場合は、実装前にその必要性と影響を明示する。
- 破壊的変更を行った場合は、最終回答で対象と移行上の注意を報告する。

## Terraform 変更後の基本検証

`.tf` または `.tf.json` ファイルを変更した場合、必要なツールが利用できるなら、リポジトリルートで以下を実行すること。

```bash
terraform fmt -check -diff -recursive
terraform validate
git diff --check
```

`terraform fmt -check -diff -recursive` がフォーマット差分によって失敗した場合は、以下を実行する。

```bash
terraform fmt -recursive
terraform fmt -check -diff -recursive
```

`terraform fmt -recursive` の後は必ず差分を確認し、変更対象と関係のない Terraform block まで変更されていないことを確認する。

最終的な working tree について、以下も確認すること。

```bash
git status --short
git diff --stat
git diff
```

コマンドを実際に実行して正常終了した場合に限り、検証が成功したと報告すること。

## terraform init を実行する条件

ドキュメントのみの変更や、Terraform の検証に初期化が必要ない場合は、`terraform init` を実行しない。

以下のいずれかに該当する場合は、`terraform init` を実行してよい。

- 新しい実行環境であり、`.terraform/` が存在しない。
- Provider または Module が未インストールであるため、`terraform validate` を実行できない。
- `terraform` block を変更した。
- `required_providers`、Provider source、Provider version constraint を変更した。
- Module source または Module version を変更した。
- ユーザーが初期化または依存関係の解決を明示的に依頼した。

通常の検証では、remote backend を初期化または参照しないよう、以下を使用する。

```bash
terraform init -backend=false -input=false
```

依存関係の upgrade がタスクに明示的に含まれていない限り、`-upgrade` を付けない。

`terraform init` により `.terraform.lock.hcl` が新規作成または更新される可能性がある。依存関係の lock が依頼範囲に含まれていない限り、新規または更新された lock file を自動的にコミットしない。

`.terraform.lock.hcl` に意図しない変更が発生した場合は、差分を確認し、最終回答で報告すること。

## terraform validate を実行する条件

Terraform 設定を変更した場合は、原則として以下を実行する。

```bash
terraform validate
```

通常の `terraform validate` のために、AWS 認証情報や AWS 実リソースへのアクセスを要求してはならない。

Provider または Module が未インストールであることだけが原因で `terraform validate` を実行できない場合は、次の順番で実行する。

```bash
terraform init -backend=false -input=false
terraform validate
```

以下のような理由で検証できなかった場合は、成功と報告してはならない。

- Terraform CLI がインストールされていない。
- 必要な Provider を取得できない。
- ネットワークアクセスが利用できない。
- 初期化が失敗した。
- Terraform または Provider のバージョンが要件を満たさない。
- その他の実行環境上の制限がある。

実行できなかった場合は、「未実行」または「環境上の制限により実行不可」として、理由を最終回答に記載する。

## terraform plan を実行してよい条件

`terraform plan` は、このリポジトリの通常の検証には含めない。

以下の条件をすべて満たす場合に限り、実行してよい。

1. ユーザーが plan の実行、または AWS へ接続する検証を明示的に依頼している。
2. 対象となる AWS アカウントとリージョンが明確である。
3. その環境を参照することが適切であると確認できている。
4. AWS 認証情報が、その検証のために意図的に提供されている。
5. 必須となる Terraform 入力値が明確であり、安全に使用できる。
6. plan の後に apply を実行しない。
7. Secret や機密情報をログ、Git 差分、コミット、最終回答へ出力しない。

AWS CloudShell に AWS 認証情報が存在するという理由だけで、`terraform plan` の実行が許可されていると判断してはならない。

plan を実行する場合は、原則として非対話モードを使用する。

```bash
terraform plan -input=false
```

ただし、このリポジトリの plan は AWS data source を参照する可能性がある。plan はインフラストラクチャを変更しないが、AWS API へのアクセスや既存リソースの refresh が発生し得ることを認識すること。

保存済み plan を後から apply する目的で作成してはならない。ユーザーが plan artifact の作成だけを明示的に依頼した場合も、実リソース変更禁止ルールと矛盾しないことを確認する。

## 禁止するインフラストラクチャ操作

このリポジトリで作業するエージェントは、AWS の実リソースを作成、変更、置換、起動、停止、削除してはならない。

以下のコマンドを実行してはならない。

```bash
terraform apply
terraform destroy
```

この禁止には、以下も含まれる。

- 対話形式の apply または destroy
- `-auto-approve` を付けた apply または destroy
- 保存済み plan の apply
- `-target` を使用した部分的な apply または destroy
- resource replacement を実行する操作
- 実リソースの管理状態やライフサイクルへ影響する import または state 操作
- AWS CLI を使用した実リソースの作成、変更、起動、停止、削除
- AWS SDK、CloudFormation、CDK、スクリプト、その他のツールを使用した実リソースの変更

実際の AWS インフラストラクチャを作成または変更してテストしてはならない。

通常の作業は、次の範囲に限定する。

- ソースコードおよび設定の静的確認
- Terraform のフォーマット
- backend を無効にした初期化
- Terraform 設定の validation
- ユーザーが明示的に許可した条件下での read-only な plan

ユーザーから AWS 実リソースを変更する操作を依頼された場合は、実行せず、禁止対象の操作であることと、代わりに実施できる安全な検証方法を報告する。

## AWS 認証情報と機密情報

通常のリポジトリ調査、フォーマット、初期化、validation では、AWS 認証情報を要求しない。

以下のルールを守ること。

- 通常の検証のために AWS access key を要求しない。
- AWS access key、secret access key、session token を表示、保存、コミットしない。
- Private key、Terraform state、機密情報を含む plan file、Secret を含む `.tfvars` を表示またはコミットしない。
- ユーザーが明示的に許可した read-only な plan を除き、AWS CloudShell などに存在する認証情報を暗黙的に利用しない。
- 明示的な依頼なしに、state や機密変数ファイルに対する `.gitignore` の保護を弱めない。
- Terraform state と plan 出力は、機密情報を含む可能性があるものとして扱う。

## README とドキュメント

現在、このリポジトリには README が存在しない。無関係な変更として README を追加してはならない。

以下のいずれかに該当する場合は、README の追加または更新が必要か確認する。

- ユーザーがドキュメントの追加または更新を明示的に依頼した。
- Terraform の `required_version` を変更した。
- `required_providers` または Provider version constraint を変更した。
- Setup、初期化、検証、plan、または利用方法を変更した。
- ユーザー向けの variable または output を追加、削除、rename した。
- 既存 variable または output の意味や動作を変更した。
- 必要な AWS 権限、対応リージョン、前提条件、費用、またはセキュリティ上の影響を変更した。
- Module を安全に利用するために必要な動作が、コードだけでは利用者に明確でない。

README の追加または更新が望ましいものの、依頼範囲外である場合は、勝手にタスクを拡大せず、最終回答の残課題として報告する。

コードコメントとドキュメントは、実際の Terraform の動作と一致させること。現在の設定が実装していない意図上の動作を、実装済みであるかのように記載してはならない。

## 検証結果の報告

実行していない検証、skip した検証、中断した検証、失敗した検証を、成功したと主張してはならない。

各検証について、次のいずれかを明確にする。

- 成功
- コードまたは設定上の問題による失敗
- 未実行
- 実行環境上の制限による実行不可

最終回答には、実行した正確なコマンドを記載する。

コマンドが失敗した場合、または実行できなかった場合は、その理由と関連する環境上の制限を記載する。

`|| true` などで終了ステータスを無視し、検証失敗を隠してはならない。

## 最終回答

最終回答には、以下を含めること。

1. 変更内容の要約
2. 追加、変更、削除したすべてのファイル
3. 実行した検証コマンドと、それぞれの成功、失敗、未実行、または実行不可の結果
4. 残っているリスク、未実施の検証、環境上の制限、互換性への懸念、または今後必要な作業

ファイルを変更していない場合は、そのことを明記する。

AWS への apply を行っていない場合、AWS 実リソース上で動作確認済みであるかのように報告してはならない。
