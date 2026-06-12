# setfacl 문법 정리

`setfacl`의 핵심은 파일·디렉터리에 ACL을 설정하기.  
`chmod`보다 세밀하게 특정 사용자, 특정 그룹, 기본 상속 권한을 지정함.

setfacl로 권한 설정 가능, getfacl로 특정 파일이나 디렉터리에 부여된 acl 조회 가능

## 기본 문법

```bash
setfacl [옵션] [ACL 엔트리] [대상 경로]
````

| 구성          | 의미                          |
| ----------- | --------------------------- |
| `setfacl`   | ACL 설정 명령                   |
| `[옵션]`      | 추가·수정·삭제·기본 ACL·재귀 적용 방식 지정 |
| `[ACL 엔트리]` | 권한을 줄 대상과 권한 내용 지정          |
| `[대상 경로]`   | ACL을 적용할 파일 또는 디렉터리 지정      |

## 기본 예시

```bash
setfacl -m g:agent-common:rwx "$AGENT_UPLOAD_DIR"
```

| 부분                   | 의미                             |
| -------------------- | ------------------------------ |
| `setfacl`            | ACL 설정                         |
| `-m`                 | ACL 항목 추가 또는 수정                |
| `g:agent-common:rwx` | `agent-common` 그룹에 `rwx` 권한 부여 |
| `$AGENT_UPLOAD_DIR`  | ACL 적용 대상 경로                   |

## ACL 엔트리 구조

```bash
g:agent-common:rwx
│ │            │
│ │            └─ 권한 지정
│ └────────────── 대상 이름 지정
└──────────────── 대상 종류 지정
```

| 위치   | 값              | 의미                |
| ---- | -------------- | ----------------- |
| 첫 번째 | `g`            | 그룹 대상 지정          |
| 두 번째 | `agent-common` | 그룹 이름 지정          |
| 세 번째 | `rwx`          | 읽기·쓰기·실행/진입 권한 부여 |

## 대상 종류 표기

| 표기  | 긴 표기    | 의미              |
| --- | ------- | --------------- |
| `u` | `user`  | 사용자 지정          |
| `g` | `group` | 그룹 지정           |
| `o` | `other` | 기타 사용자 지정       |
| `m` | `mask`  | ACL 최대 허용 권한 지정 |

## ACL 엔트리 형식

| 형식                   | 의미                              |
| -------------------- | ------------------------------- |
| `u:alice:rwx`        | `alice` 사용자에게 `rwx` 권한 부여       |
| `g:agent-common:rwx` | `agent-common` 그룹에게 `rwx` 권한 부여 |
| `u::rwx`             | 파일 소유자 권한 지정                    |
| `g::r-x`             | 파일 소유 그룹 권한 지정                  |
| `o::---`             | 기타 사용자 권한 제거                    |
| `m::rwx`             | ACL mask 지정                     |

## 권한 표기

| 표기  | 파일 기준 | 디렉터리 기준          |
| --- | ----- | ---------------- |
| `r` | 파일 읽기 | 디렉터리 목록 조회       |
| `w` | 파일 쓰기 | 파일 생성·삭제·이름 변경   |
| `x` | 파일 실행 | 디렉터리 진입·내부 경로 접근 |
| `-` | 권한 없음 | 권한 없음            |

## 주요 옵션

| 옵션          | 의미                  |
| ----------- | ------------------- |
| `-m`        | ACL 항목 추가 또는 수정     |
| `-x`        | ACL 항목 제거           |
| `-b`        | 확장 ACL 전체 제거        |
| `-k`        | 기본 ACL 전체 제거        |
| `-d`        | default ACL 대상으로 지정 |
| `-R`        | 하위 항목까지 재귀 적용       |
| `--set`     | ACL 전체 대체           |
| `--restore` | ACL 복원              |

## `-m` 옵션

| 명령                                | 의미                       |
| --------------------------------- | ------------------------ |
| `setfacl -m u:alice:rwx file.txt` | `alice` 사용자 ACL 추가 또는 수정 |
| `setfacl -m g:dev:r-x dir`        | `dev` 그룹 ACL 추가 또는 수정    |
| `setfacl -m o::--- file.txt`      | 기타 사용자 권한 제거             |
| `setfacl -m m::rwx file.txt`      | ACL mask를 `rwx`로 설정      |

## `-d` 옵션

| 명령                            | 의미                           |
| ----------------------------- | ---------------------------- |
| `setfacl -d -m g:dev:rwx dir` | 새 항목에 상속될 `dev` 그룹 기본 ACL 설정 |
| `setfacl -d -m o::--- dir`    | 새 항목에 상속될 기타 사용자 기본 권한 제거    |
| `setfacl -d -x g:dev dir`     | default ACL에서 `dev` 그룹 항목 제거 |
| `setfacl -k dir`              | default ACL 전체 제거            |

`-d`는 default ACL 지정 옵션.
디렉터리 안에 새로 생성될 파일·디렉터리에 상속될 ACL 설정.
일반 파일에는 의미 없음.

## 현재 ACL과 default ACL 비교

| 구분             | 명령                                                     | 적용 범위                          |
| -------------- | ------------------------------------------------------ | ------------------------------ |
| 현재 ACL         | `setfacl -m g:dev:rwx dir`                             | `dir` 자체                       |
| default ACL    | `setfacl -d -m g:dev:rwx dir`                          | 앞으로 `dir` 안에 생성될 항목            |
| 재귀 현재 ACL      | `setfacl -R -m g:dev:rwx dir`                          | 이미 존재하는 하위 파일·디렉터리             |
| 재귀 default ACL | `find dir -type d -exec setfacl -d -m g:dev:rwx {} \;` | 이미 존재하는 하위 디렉터리의 future 상속 ACL |

## `-x` 옵션

| 명령                                   | 의미                                    |
| ------------------------------------ | ------------------------------------- |
| `setfacl -x u:alice file.txt`        | `alice` 사용자 ACL 제거                    |
| `setfacl -x g:agent-common file.txt` | `agent-common` 그룹 ACL 제거              |
| `setfacl -d -x g:agent-common dir`   | default ACL에서 `agent-common` 그룹 항목 제거 |

`-x` 사용 시 권한 부분 생략.

| 사용  | 예시                                       |
| --- | ---------------------------------------- |
| 권장  | `setfacl -x g:agent-common file.txt`     |
| 비권장 | `setfacl -x g:agent-common:rwx file.txt` |

## 확장 ACL 제거

| 명령                    | 의미                    |
| --------------------- | --------------------- |
| `setfacl -b file.txt` | 확장 ACL 전체 제거          |
| `setfacl -k dir`      | default ACL 전체 제거     |
| `setfacl -R -b dir`   | 하위 항목 포함 확장 ACL 전체 제거 |

## 재귀 적용

| 명령                                                              | 의미                          |
| --------------------------------------------------------------- | --------------------------- |
| `setfacl -R -m g:agent-common:rwx dir`                          | 기존 하위 파일·디렉터리에 ACL 재귀 부여    |
| `setfacl -R -x g:agent-common dir`                              | 기존 하위 파일·디렉터리에서 ACL 재귀 제거   |
| `setfacl -R -b dir`                                             | 기존 하위 파일·디렉터리의 확장 ACL 재귀 제거 |
| `find dir -type d -exec setfacl -d -m g:agent-common:rwx {} \;` | 모든 하위 디렉터리에 default ACL 부여  |

## mask 정리

| 항목     | 의미                                 |
| ------ | ---------------------------------- |
| `mask` | ACL의 최대 유효 권한                      |
| 적용 대상  | 특정 사용자 ACL, 특정 그룹 ACL, 소유 그룹 권한    |
| 미적용 대상 | 소유자 권한, 기타 사용자 권한                  |
| 주의점    | ACL에 `rwx`가 보여도 mask가 낮으면 실제 권한 축소 |

## mask 예시

| ACL 출력                   | 의미             |
| ------------------------ | -------------- |
| `group:agent-common:rwx` | 명목상 `rwx` 권한   |
| `mask::r--`              | 최대 허용 권한 `r--` |
| `#effective:r--`         | 실제 적용 권한 `r--` |

## ACL 확인

```bash
getfacl "$AGENT_UPLOAD_DIR"
```

## getfacl 출력 예시

```bash
# file: upload_files
# owner: agent-admin
# group: agent-common
user::rwx
group::rwx
group:agent-common:rwx
mask::rwx
other::---
default:user::rwx
default:group::rwx
default:group:agent-common:rwx
default:mask::rwx
default:other::---
```

## getfacl 출력 해석

| 출력                               | 의미                             |
| -------------------------------- | ------------------------------ |
| `user::rwx`                      | 소유자 권한                         |
| `group::rwx`                     | 소유 그룹 권한                       |
| `group:agent-common:rwx`         | `agent-common` 그룹 현재 ACL       |
| `mask::rwx`                      | ACL 최대 허용 권한                   |
| `other::---`                     | 기타 사용자 권한 없음                   |
| `default:user::rwx`              | 새 항목의 기본 소유자 권한                |
| `default:group::rwx`             | 새 항목의 기본 소유 그룹 권한              |
| `default:group:agent-common:rwx` | 새 항목의 기본 `agent-common` 그룹 ACL |
| `default:mask::rwx`              | 새 항목의 기본 ACL mask              |
| `default:other::---`             | 새 항목의 기본 기타 사용자 권한 없음          |

## 공유 디렉터리 설정 예시

```bash
chown agent-admin:agent-common "$AGENT_UPLOAD_DIR"
chmod 2770 "$AGENT_UPLOAD_DIR"
setfacl -m g:agent-common:rwx "$AGENT_UPLOAD_DIR"
setfacl -d -m g:agent-common:rwx "$AGENT_UPLOAD_DIR"
setfacl -m o::--- "$AGENT_UPLOAD_DIR"
setfacl -d -m o::--- "$AGENT_UPLOAD_DIR"
```

| 명령                                                     | 의미                                         |
| ------------------------------------------------------ | ------------------------------------------ |
| `chown agent-admin:agent-common "$AGENT_UPLOAD_DIR"`   | 소유자 `agent-admin`, 소유 그룹 `agent-common` 설정 |
| `chmod 2770 "$AGENT_UPLOAD_DIR"`                       | 소유자·그룹 `rwx`, 기타 사용자 차단, setgid 적용         |
| `setfacl -m g:agent-common:rwx "$AGENT_UPLOAD_DIR"`    | 현재 디렉터리에 `agent-common` 그룹 ACL 부여          |
| `setfacl -d -m g:agent-common:rwx "$AGENT_UPLOAD_DIR"` | 새 항목에 `agent-common` 기본 ACL 부여             |
| `setfacl -m o::--- "$AGENT_UPLOAD_DIR"`                | 현재 디렉터리의 기타 사용자 권한 제거                      |
| `setfacl -d -m o::--- "$AGENT_UPLOAD_DIR"`             | 새 항목의 기타 사용자 기본 권한 제거                      |

## 요약

| 목적             | 명령                            |
| -------------- | ----------------------------- |
| 특정 사용자 권한 부여   | `setfacl -m u:alice:rwx file` |
| 특정 그룹 권한 부여    | `setfacl -m g:dev:rwx dir`    |
| 기타 사용자 차단      | `setfacl -m o::--- file`      |
| default ACL 부여 | `setfacl -d -m g:dev:rwx dir` |
| 특정 ACL 제거      | `setfacl -x g:dev file`       |
| default ACL 제거 | `setfacl -k dir`              |
| 확장 ACL 전체 제거   | `setfacl -b file`             |
| 재귀 ACL 적용      | `setfacl -R -m g:dev:rwx dir` |
| ACL 확인         | `getfacl file`                |

```
