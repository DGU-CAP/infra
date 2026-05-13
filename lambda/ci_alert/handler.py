import json
import os
import hmac
import hashlib
import boto3
import urllib.request


def get_secret(secret_arn: str) -> dict:
    sm = boto3.client("secretsmanager", region_name=os.environ["AWS_REGION"])
    resp = sm.get_secret_value(SecretId=secret_arn)
    return json.loads(resp["SecretString"])


def verify_signature(payload_body: bytes, signature: str, secret: str) -> bool:
    expected = "sha256=" + hmac.new(
        secret.encode(), payload_body, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)


def fetch_failed_logs(repo: str, run_id: int, token: str) -> str:
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }

    # 실패한 job 목록 조회
    req = urllib.request.Request(
        f"https://api.github.com/repos/{repo}/actions/runs/{run_id}/jobs",
        headers=headers,
    )
    with urllib.request.urlopen(req) as resp:
        jobs_data = json.loads(resp.read())

    log_text = ""
    failed_steps_summary = []

    for job in jobs_data.get("jobs", []):
        if job["conclusion"] != "failure":
            continue

        for step in job.get("steps", []):
            if step["conclusion"] == "failure":
                failed_steps_summary.append(f"{job['name']} > {step['name']}")

        # job 로그 수집 (마지막 3000자)
        try:
            # GitHub logs endpoint → 302 redirect to signed URL (no auth needed)
            class NoRedirect(urllib.request.HTTPRedirectHandler):
                def redirect_request(self, req, fp, code, msg, hdrs, newurl):
                    return None

            opener = urllib.request.build_opener(NoRedirect())
            try:
                opener.open(urllib.request.Request(
                    f"https://api.github.com/repos/{repo}/actions/jobs/{job['id']}/logs",
                    headers=headers,
                ))
            except urllib.error.HTTPError as redir:
                log_url = redir.headers.get("Location")

            with urllib.request.urlopen(log_url) as r:
                raw = r.read().decode("utf-8", errors="replace")
                log_text += f"\n=== Job: {job['name']} ===\n{raw[-3000:]}"
        except Exception as e:
            log_text += f"\n=== Job: {job['name']} ===\n[로그 수집 실패: {e}]"

    summary = "실패 스텝: " + ", ".join(failed_steps_summary) if failed_steps_summary else "실패 스텝 정보 없음"
    return f"{summary}\n{log_text}"


def analyze_with_bedrock(logs: str, repo: str, workflow: str, branch: str) -> str:
    bedrock = boto3.client("bedrock-runtime", region_name=os.environ["AWS_REGION"])

    prompt = f"""GitHub Actions CI가 실패했습니다. 아래 로그를 분석해서 한국어로 간결하게 답해주세요.

레포지토리: {repo}
워크플로: {workflow}
브랜치: {branch}

실패 로그:
{logs[:4000]}

다음 형식으로만 답하세요:
**원인 요약** (1-2줄)
**상세 원인** (구체적으로)
**해결 방법** (실행 가능한 단계)"""

    resp = bedrock.invoke_model(
        modelId="anthropic.claude-3-5-sonnet-20240620-v1:0",
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 800,
            "messages": [{"role": "user", "content": prompt}],
        }),
        contentType="application/json",
        accept="application/json",
    )
    result = json.loads(resp["body"].read())
    return result["content"][0]["text"]


def post_to_slack(webhook_url: str, repo: str, workflow: str, branch: str, run_url: str, analysis: str):
    payload = {
        "blocks": [
            {
                "type": "header",
                "text": {"type": "plain_text", "text": "CI 실패 알림"},
            },
            {
                "type": "section",
                "fields": [
                    {"type": "mrkdwn", "text": f"*레포:* `{repo}`"},
                    {"type": "mrkdwn", "text": f"*워크플로:* `{workflow}`"},
                    {"type": "mrkdwn", "text": f"*브랜치:* `{branch}`"},
                ],
            },
            {
                "type": "section",
                "text": {"type": "mrkdwn", "text": f"*Bedrock 분석:*\n{analysis}"},
            },
            {
                "type": "actions",
                "elements": [
                    {
                        "type": "button",
                        "text": {"type": "plain_text", "text": "GitHub Actions 보기"},
                        "url": run_url,
                        "style": "danger",
                    }
                ],
            },
        ]
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        webhook_url, data=data, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        resp.read()


def handler(event, context):
    body = event.get("body", "")
    body_bytes = body.encode("utf-8") if isinstance(body, str) else body

    headers = {k.lower(): v for k, v in event.get("headers", {}).items()}
    signature = headers.get("x-hub-signature-256", "")
    event_type = headers.get("x-github-event", "")

    secrets = get_secret(os.environ["SECRET_ARN"])

    if not verify_signature(body_bytes, signature, secrets["github_webhook_secret"]):
        return {"statusCode": 401, "body": "Unauthorized"}

    if event_type != "workflow_run":
        return {"statusCode": 200, "body": "ignored"}

    payload = json.loads(body)
    workflow_run = payload.get("workflow_run", {})

    if workflow_run.get("conclusion") != "failure":
        return {"statusCode": 200, "body": "not a failure"}

    repo = payload["repository"]["full_name"]
    workflow_name = workflow_run["name"]
    branch = workflow_run["head_branch"]
    run_id = workflow_run["id"]
    run_url = workflow_run["html_url"]

    logs = fetch_failed_logs(repo, run_id, secrets["github_token"])
    analysis = analyze_with_bedrock(logs, repo, workflow_name, branch)
    post_to_slack(secrets["slack_webhook_url"], repo, workflow_name, branch, run_url, analysis)

    return {"statusCode": 200, "body": "ok"}
