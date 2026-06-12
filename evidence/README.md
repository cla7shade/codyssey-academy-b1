# B1-1 Evidence

수집 시각: Tue May 26 20:44:57 KST 2026
컨테이너: b1-1-agent

| # | 파일 | 체크리스트 항목 |
|---|------|-----------------|
| 01 | 01_ssh.txt | SSH 포트 20022 + PermitRootLogin no + ss 리슨 |
| 02 | 02_ufw.txt | UFW 활성 + 20022/15034 만 허용 |
| 03 | 03_accounts.txt | agent-admin/dev/test 계정, agent-common/core 그룹 |
| 04 | 04_dirs_acl.txt | 디렉토리 구조 / 권한 / ACL / 키 파일 / monitor.sh |
| 05 | 05_boot_sequence.txt | Boot 5/5 [OK] + Agent READY |
| 06 | 06_monitor_run.txt | monitor.sh 실행 결과 |
| 07 | 07_crontab.txt | agent-admin crontab 매분 등록 |
| 08 | 08_monitor_log_tail.txt | monitor.log 누적 (cron 매분 자동 실행 증거) |

각 파일 첫 줄에 사용한 명령(`$ ...`)이 함께 기록되어 있다.
