GitHub PR의 코드를 리뷰합니다.
사용법: `/review-pr <PR번호>` 또는 현재 브랜치의 PR을 자동으로 감지합니다.

## 진행 순서

1. **PR 정보 가져오기**
   - 인자로 PR 번호가 주어진 경우: `gh pr view <PR번호> --json title,body,files,commits`
   - 인자가 없는 경우: `gh pr view --json title,body,files,commits` (현재 브랜치 기준)
   - PR을 찾을 수 없으면 사용자에게 번호를 물어보세요

2. **변경 diff 가져오기**
   `gh pr diff <PR번호>`

3. **아래 관점으로 코드를 리뷰하세요:**

### 인프라 코드 리뷰 기준 (Terraform)
- **정확성**: 리소스 설정이 의도한 아키텍처와 일치하는가
- **보안**: 불필요하게 열린 보안 그룹, 퍼블릭 노출 여부, IAM 권한 과다 부여
- **태그**: 모든 리소스에 `Name`, `Environment` 태그가 있는가
- **고가용성**: 단일 AZ 의존 여부, 장애 포인트 존재 여부
- **비용**: 불필요하게 비싼 리소스 선택 여부
- **네이밍**: `${var.project_name}-<역할>` 형식 준수 여부
- **변수화**: 하드코딩된 값이 변수로 분리되어 있는가
- **EKS 연동 고려**: 추후 EKS 연동에 문제가 생길 설정은 없는가

### 일반 리뷰 기준
- PR 범위가 이슈와 일치하는가 (과도한 변경 포함 여부)
- 의도하지 않은 파일 포함 여부 (`.terraform/`, `*.tfstate` 등)

4. **리뷰 결과 출력 형식:**

```
## PR 리뷰 결과: <PR 제목>

### 요약
(전반적인 평가 한 줄)

### 필수 수정 (Blocking)
- ...

### 개선 제안 (Non-blocking)
- ...

### 잘된 점
- ...

### 결론
APPROVE / REQUEST CHANGES / COMMENT
```

5. **GitHub에 리뷰 남기기** (사용자 동의 후)
   - `APPROVE` 또는 `REQUEST CHANGES` 중 선택하여 `gh pr review` 로 리뷰를 제출하세요
   - 구체적인 코멘트는 `gh pr review <번호> --comment -b "<내용>"` 으로 추가
