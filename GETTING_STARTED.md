# 팀원 온보딩 가이드

DGU-CAP 인프라 레포지토리 초기 세팅 가이드입니다.

---

## 사전 준비

아래 도구들을 설치해주세요.

| 도구 | 설치 확인 | 설치 링크 |
|---|---|---|
| AWS CLI | `aws --version` | https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html |
| Terraform | `terraform -version` | https://developer.hashicorp.com/terraform/install |
| GitHub CLI | `gh --version` | https://cli.github.com |
| Claude Code | `claude --version` | https://claude.ai/code |

---

## 1. AWS 프로필 설정

팀 리더에게 공용 AWS Access Key를 전달받은 후 등록합니다.

```bash
aws configure --profile dgu-cap
```

```
AWS Access Key ID: (팀 리더에게 전달받은 키)
AWS Secret Access Key: (팀 리더에게 전달받은 시크릿)
Default region name: ap-northeast-2
Default output format: json
```

등록 확인:
```bash
aws sts get-caller-identity --profile dgu-cap
```

계정 정보가 출력되면 정상입니다.

---

## 2. GitHub 인증

```bash
gh auth login
```

- GitHub.com 선택
- HTTPS 선택
- 브라우저 인증 진행

---

## 3. 레포 클론

```bash
git clone https://github.com/DGU-CAP/infra.git
cd infra
```

---

## 4. Terraform 초기화

```bash
cd terraform
export AWS_PROFILE=dgu-cap
terraform init
```

`Successfully configured the backend "s3"` 메시지가 나오면 완료입니다.

---

## 5. Claude Code 설정 (선택)

Claude Code를 사용하면 이슈 생성, PR, 코드리뷰를 슬래시 커맨드로 처리할 수 있습니다.

```bash
# 레포 루트에서 실행
claude
```

사용 가능한 커맨드:

| 커맨드 | 설명 |
|---|---|
| `/new-issue` | GitHub 이슈 생성 |
| `/new-pr` | PR 생성 (이슈 연결 필수) |
| `/review-pr <번호>` | PR 코드리뷰 |

---

## 작업 흐름

모든 작업은 아래 순서를 따릅니다. **이슈 없는 PR은 올리지 않습니다.**

```
1. /new-issue       → 이슈 생성
2. git checkout -b  → 브랜치 생성 (feat/#이슈번호-설명)
3. 작업
4. git push
5. /new-pr          → PR 생성
6. /review-pr       → 코드리뷰 후 머지
```

### 브랜치 네이밍

```
feat/#12-add-eks-cluster
fix/#7-subnet-cidr
chore/#3-update-provider
```

### 커밋 메시지

```
feat: EKS 클러스터 Terraform 모듈 추가
fix: Private 서브넷 CIDR 중복 수정
```

---

## Terraform 주요 명령어

```bash
cd terraform

terraform plan      # 변경사항 미리 확인 (PR 전 필수)
terraform apply     # 실제 적용 (Actions에서 수동 실행)
```

> `terraform apply` 는 GitHub Actions에서 수동으로 실행합니다.
> 로컬에서 직접 실행이 필요한 경우 팀 리더와 협의 후 진행하세요.

---

## 문의

세팅 중 문제가 생기면 팀 리더에게 문의하세요.
