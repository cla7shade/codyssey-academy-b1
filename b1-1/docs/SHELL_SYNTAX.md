# 쉘 조건문 문법

쉘 조건문은 `if`, `[ ... ]`, `[[ ... ]]`, `(( ... ))`를 상황에 맞게 사용함. 파일 검사는 `-f`, `-e`, `-d` 같은 테스트 옵션으로 처리하고, 조건 조합은 `&&`, `||`, `!`로 처리함.

## 기본 구조

```bash id="b5m0ov"
if [ 조건 ]; then
  명령
elif [ 다른조건 ]; then
  명령
else
  명령
fi
```

`[`와 `]`는 조건식을 감싸는 문법처럼 보이지만 실제로는 `test` 명령의 다른 형태임. 그래서 내부 공백이 필요함.

```bash id="55eez5"
if [ -f "$file" ]; then
  echo "일반 파일임"
fi
```

## 조건문 종류

| 형태          | 의미                     |
| ----------- | ---------------------- |
| `[ 조건 ]`    | POSIX `sh` 호환 조건문임     |
| `[[ 조건 ]]`  | Bash, Zsh에서 쓰는 확장 조건문임 |
| `(( 산술식 ))` | 숫자 계산 조건에 쓰는 산술 조건문임   |

```bash id="esyb2h"
if [ -f "$file" ]; then
  echo "일반 파일임"
fi
```

```bash id="cl7yu5"
if [[ -f "$file" && -r "$file" ]]; then
  echo "읽을 수 있는 일반 파일임"
fi
```

```bash id="xm4c78"
if (( count > 10 )); then
  echo "10보다 큼"
fi
```

## 파일 검사 옵션

| 옵션               | 의미                                                 |
| ---------------- | -------------------------------------------------- |
| `-e 파일`          | 경로에 파일, 디렉터리, 링크 등 어떤 항목이든 존재하는지 검사함               |
| `-f 파일`          | 경로가 존재하며 일반 파일인지 검사함                               |
| `-d 파일`          | 경로가 존재하며 디렉터리인지 검사함                                |
| `-L 파일`, `-h 파일` | 경로가 심볼릭 링크인지 검사함                                   |
| `-r 파일`          | 현재 사용자가 해당 경로를 읽을 수 있는지 검사함                        |
| `-w 파일`          | 현재 사용자가 해당 경로에 쓸 수 있는지 검사함                         |
| `-x 파일`          | 현재 사용자가 해당 경로를 실행할 수 있는지 검사함. 디렉터리라면 진입할 수 있는지 검사함 |
| `-s 파일`          | 파일이 존재하고 크기가 0보다 큰지 검사함                            |
| `-b 파일`          | 경로가 블록 디바이스 파일인지 검사함                               |
| `-c 파일`          | 경로가 문자 디바이스 파일인지 검사함                               |
| `-p 파일`          | 경로가 FIFO, 즉 named pipe인지 검사함                       |
| `-S 파일`          | 경로가 소켓 파일인지 검사함                                    |
| `-O 파일`          | 현재 유효 사용자 ID가 해당 파일의 소유자인지 검사함                     |
| `-G 파일`          | 현재 유효 그룹 ID가 해당 파일의 그룹 소유자인지 검사함                   |
| `파일1 -nt 파일2`    | 파일1의 수정 시간이 파일2보다 최신인지 검사함                         |
| `파일1 -ot 파일2`    | 파일1의 수정 시간이 파일2보다 오래되었는지 검사함                       |
| `파일1 -ef 파일2`    | 두 경로가 같은 디바이스와 inode를 가리키는지 검사함                    |

```bash id="kbg6xh"
if [ -e "$path" ]; then
  echo "경로가 존재함"
fi
```

```bash id="40wsss"
if [ -f "$path" ]; then
  echo "일반 파일임"
fi
```

```bash id="kj7zmv"
if [ -d "$path" ]; then
  echo "디렉터리임"
fi
```

```bash id="ivp9c1"
if [ -s "$file" ]; then
  echo "비어 있지 않은 파일임"
fi
```

```bash id="aalm0t"
if [ -x "$script" ]; then
  echo "실행 가능함"
fi
```

## 문자열 조건

| 표현             | 의미                                                  |
| -------------- | --------------------------------------------------- |
| `-z "$str"`    | 문자열 길이가 0인지 검사함                                     |
| `-n "$str"`    | 문자열 길이가 0이 아닌지 검사함                                  |
| `"$a" = "$b"`  | 두 문자열이 같은지 검사함                                      |
| `"$a" != "$b"` | 두 문자열이 다른지 검사함                                      |
| `"$a" < "$b"`  | 문자열 `a`가 사전순으로 `b`보다 앞서는지 검사함. `[[ ... ]]`에서 사용 권장함 |
| `"$a" > "$b"`  | 문자열 `a`가 사전순으로 `b`보다 뒤인지 검사함. `[[ ... ]]`에서 사용 권장함  |

```bash id="7070c8"
if [ -z "$name" ]; then
  echo "name이 비어 있음"
fi
```

```bash id="oj7yhw"
if [ -n "$name" ]; then
  echo "name이 비어 있지 않음"
fi
```

```bash id="45drqn"
if [ "$env" = "prod" ]; then
  echo "운영 환경임"
fi
```

`[` 안에서 `<`, `>`를 쓰면 리다이렉션으로 해석될 수 있으므로 이스케이프가 필요함.

```bash id="0b5a62"
if [ "$a" \< "$b" ]; then
  echo "a가 b보다 앞섬"
fi
```

`[[ ... ]]`에서는 이스케이프 없이 사용 가능함.

```bash id="n09km5"
if [[ "$a" < "$b" ]]; then
  echo "a가 b보다 앞섬"
fi
```

## 숫자 조건

| 표현          | 의미                     |
| ----------- | ---------------------- |
| `$a -eq $b` | 두 숫자가 같은지 검사함          |
| `$a -ne $b` | 두 숫자가 다른지 검사함          |
| `$a -lt $b` | `a`가 `b`보다 작은지 검사함     |
| `$a -le $b` | `a`가 `b`보다 작거나 같은지 검사함 |
| `$a -gt $b` | `a`가 `b`보다 큰지 검사함      |
| `$a -ge $b` | `a`가 `b`보다 크거나 같은지 검사함 |

```bash id="8le8pe"
if [ "$count" -eq 0 ]; then
  echo "0임"
fi
```

```bash id="ly71aw"
if [ "$count" -gt 10 ]; then
  echo "10보다 큼"
fi
```

```bash id="3ubpa9"
if (( count > 10 )); then
  echo "10보다 큼"
fi
```

## 논리 연산자

| 연산자  | 의미      | 권장 사용 위치                       |        |                               |
| ---- | ------- | ------------------------------ | ------ | ----------------------------- |
| `&&` | AND 조건임 | `[ ... ]` 바깥 또는 `[[ ... ]]` 안  |        |                               |
| `    |         | `                              | OR 조건임 | `[ ... ]` 바깥 또는 `[[ ... ]]` 안 |
| `!`  | NOT 조건임 | `[ ... ]`, `[[ ... ]]` 안       |        |                               |
| `-a` | AND 조건임 | `[ ... ]` 안에서 사용 가능하지만 권장하지 않음 |        |                               |
| `-o` | OR 조건임  | `[ ... ]` 안에서 사용 가능하지만 권장하지 않음 |        |                               |

```bash id="77bg47"
if [ -f "$file" ] && [ -r "$file" ]; then
  echo "읽을 수 있는 일반 파일임"
fi
```

```bash id="eqto9s"
if [[ -f "$file" && -r "$file" ]]; then
  echo "읽을 수 있는 일반 파일임"
fi
```

```bash id="9ekxfw"
if [ -d "$path" ] || [ -f "$path" ]; then
  echo "디렉터리 또는 일반 파일임"
fi
```

```bash id="ggawmu"
if [[ -d "$path" || -f "$path" ]]; then
  echo "디렉터리 또는 일반 파일임"
fi
```

```bash id="mw4myk"
if [ ! -e "$file" ]; then
  echo "존재하지 않음"
fi
```

`!`는 조건 앞에서 부정 연산자로 쓰이지만, 변수 확장 안에서 쓰이면 전혀 다른 의미가 됨. `${!var}` 형태는 Bash의 간접 변수 참조(indirect expansion) 임. `var`가 담고 있는 문자열을 변수 이름으로 다시 해석해 그 변수의 값을 가져옴.

```bash id="ind001"
name="AGENT_HOME"
AGENT_HOME="/home/agent-admin/agent-app"

echo "$name"     # AGENT_HOME 출력함
echo "${!name}"  # /home/agent-admin/agent-app 출력함
```

| 표현             | 의미                                      |
| -------------- | --------------------------------------- |
| `$var`         | `var`의 값을 그대로 가져옴                       |
| `${!var}`      | `var`의 값을 변수 이름으로 보고, 그 이름의 변수 값을 가져옴   |
| `${!var:-기본값}` | 간접 참조 결과가 unset이거나 빈 문자열이면 기본값으로 대체함    |

`${!var:-}` 형태는 `set -u` 환경에서 변수가 정의되지 않았는지 검사할 때 유용함. `set -u`가 켜져 있으면 정의되지 않은 변수를 그냥 확장하는 순간 스크립트가 죽기 때문에, `:-`로 빈 문자열 기본값을 둬서 "비어 있는지" 자체를 검사할 수 있게 함.

```bash id="ind002"
#!/usr/bin/env bash
set -euo pipefail

for v in AGENT_HOME AGENT_PORT AGENT_API_KEY; do
  [ -n "${!v:-}" ] || { echo "$v 환경변수가 필요함" >&2; exit 1; }
done
```

여러 필수 환경변수를 한 번의 루프로 검증할 때 자주 사용함. 변수 이름 목록을 데이터처럼 다룰 수 있어 검증 로직이 짧아짐.

`-a`, `-o`는 조건이 복잡해질수록 해석이 헷갈릴 수 있으므로 `&&`, `||` 사용이 더 나음.

```bash id="rwr2e7"
if [ -f "$file" -a -r "$file" ]; then
  echo "읽을 수 있는 일반 파일임"
fi
```

```bash id="5xwys7"
if [ -f "$file" ] && [ -r "$file" ]; then
  echo "읽을 수 있는 일반 파일임"
fi
```

## 자주 쓰는 형태

```bash id="558kt0"
if [[ -f "$file" && -r "$file" ]]; then
  cat "$file"
fi
```

```bash id="os6rpt"
if [[ ! -e "$file" ]]; then
  touch "$file"
fi
```

```bash id="jjsjd9"
if [[ ! -d "$dir" ]]; then
  mkdir -p "$dir"
fi
```

```bash id="4i7eup"
if [[ $# -eq 0 ]]; then
  echo "인자가 필요함"
  exit 1
fi
```

```bash id="23zhq0"
if grep -q "ERROR" app.log; then
  echo "에러 로그가 있음"
else
  echo "에러 로그가 없음"
fi
```

```bash id="8831ld"
if ! command -v git >/dev/null 2>&1; then
  echo "git이 설치되어 있지 않음"
fi
```

## `[[ ... ]]`의 패턴 조건

`[[ ... ]]`에서는 오른쪽 값에 와일드카드 패턴을 사용할 수 있음.

```bash id="6wo0a6"
if [[ "$file" == *.log ]]; then
  echo "로그 파일임"
fi
```

정규식 검사는 `=~`를 사용함.

```bash id="xvn1wh"
if [[ "$name" =~ ^[a-zA-Z0-9_]+$ ]]; then
  echo "허용된 이름 형식임"
fi
```

## 한 줄 조건문

```bash id="l7tk4l"
[ -f "$file" ] && echo "파일 있음"
```

```bash id="og6hp1"
[ -f "$file" ] || echo "파일 없음"
```

```bash id="4h4qwu"
mkdir -p "$dir" && echo "디렉터리 준비됨"
```

## 사용 기준

Bash 스크립트라면 `[[ ... ]]`를 기본으로 사용하는 편이 좋음.

```bash id="e3hwzo"
if [[ -f "$file" && -r "$file" ]]; then
  echo "처리 가능함"
fi
```

POSIX `sh` 호환이 필요하면 `[ ... ]`를 사용함.

```bash id="rxkn8h"
if [ -f "$file" ] && [ -r "$file" ]; then
  echo "처리 가능함"
fi
```

정리하면 `-e`는 경로 존재 여부를 검사함. `-f`는 일반 파일 여부를 검사함. `-d`는 디렉터리 여부를 검사함. `&&`는 둘 다 참인지 검사함. `||`는 둘 중 하나라도 참인지 검사함. `!`는 조건을 부정함. Bash에서는 복잡한 조건에 `[[ ... ]]`를 사용하는 편이 안전함.


쉘 스크립트의 첫 줄에는 보통 **어떤 쉘로 이 파일을 실행할지 지정하는 shebang**을 적음. Bash 스크립트라면 `#!/bin/bash` 또는 `#!/usr/bin/env bash`를 사용함. 그리고 `set -euo pipefail`은 스크립트가 실패를 숨기지 않고 즉시 멈추도록 만드는 안전 설정임.

## shebang

```bash id="yfb4qy"
#!/bin/bash
```

```bash id="lmqfk7"
#!/usr/bin/env bash
```

shebang은 스크립트 파일의 첫 줄에 적는 실행 지시문임. 파일을 직접 실행할 때 운영체제가 이 줄을 보고 어떤 인터프리터로 실행할지 결정함.

```bash id="yzktlb"
chmod +x script.sh
./script.sh
```

`./script.sh`처럼 파일을 직접 실행하면 shebang이 적용됨.

```bash id="lqphq2"
bash script.sh
```

`bash script.sh`처럼 실행하면 사용자가 이미 Bash를 지정한 것이므로 shebang에 의존하지 않음.

```bash id="m0bqb0"
sh script.sh
```

`sh script.sh`처럼 실행하면 Bash 스크립트라도 `sh`로 실행됨. 스크립트 안에 Bash 전용 문법이 있으면 실패할 수 있음.

## `#!/bin/bash`

```bash id="0jkhur"
#!/bin/bash

echo "Bash로 실행함"
```

`#!/bin/bash`는 `/bin/bash` 경로에 있는 Bash로 스크립트를 실행하라는 의미임.

| 항목          | 의미                |
| ----------- | ----------------- |
| `#!`        | shebang 시작 표시임    |
| `/bin/bash` | 사용할 인터프리터의 절대 경로임 |

`#!/bin/bash`는 실행할 Bash 위치를 명확히 고정함. 서버, 컨테이너, 리눅스 시스템처럼 Bash 위치가 확실한 환경에서 사용하기 좋음.

## `#!/usr/bin/env bash`

```bash id="rnqupb"
#!/usr/bin/env bash

echo "PATH에서 Bash를 찾아 실행함"
```

`#!/usr/bin/env bash`는 `/usr/bin/env`를 실행하고, `env`가 `PATH`에서 `bash`를 찾아 실행하게 하는 방식임.

| 항목             | 의미                     |
| -------------- | ---------------------- |
| `#!`           | shebang 시작 표시임         |
| `/usr/bin/env` | 환경에서 명령을 찾아 실행하는 프로그램임 |
| `bash`         | `PATH`에서 찾을 인터프리터 이름임  |

`#!/usr/bin/env bash`는 Bash 위치가 환경마다 다를 때 유연함. 개발자 로컬 환경, macOS, 버전 관리 도구를 쓰는 환경에서 자주 사용함.

## 두 방식 비교

| 형태                    | 의미                      | 특징           |
| --------------------- | ----------------------- | ------------ |
| `#!/bin/bash`         | `/bin/bash`를 직접 실행함     | 경로가 고정되어 명확함 |
| `#!/usr/bin/env bash` | `PATH`에서 `bash`를 찾아 실행함 | 환경 차이에 더 유연함 |

실행할 Bash 경로를 정확히 고정하고 싶으면 `#!/bin/bash`를 사용함. 사용자의 `PATH`에 잡힌 Bash를 사용하고 싶으면 `#!/usr/bin/env bash`를 사용함.

## Bash shebang이 필요한 경우

스크립트에서 Bash 전용 문법을 쓰면 Bash로 실행되도록 지정해야 함.

```bash id="1y97uf"
#!/usr/bin/env bash

files=("a.txt" "b.txt")

if [[ -f "${files[0]}" ]]; then
  echo "일반 파일임"
fi
```

아래 문법들은 Bash 전용 문법에 가까우므로 Bash shebang을 쓰는 편이 맞음.

| 문법                | 의미                |
| ----------------- | ----------------- |
| `[[ ... ]]`       | Bash 확장 조건문임      |
| `(( ... ))`       | 산술 조건문임           |
| `array=("a" "b")` | 배열 문법임            |
| `${var//old/new}` | 문자열 치환 확장임        |
| `source file.sh`  | 현재 쉘에서 파일을 읽어 실행함 |

POSIX `sh` 호환 스크립트라면 Bash 전용 문법을 피하고 `#!/bin/sh`를 사용함.

```sh id="wfi10x"
#!/bin/sh

if [ -f "$file" ]; then
  echo "일반 파일임"
fi
```

## `set`

```bash id="0j49b1"
set -euo pipefail
```

`set`은 현재 쉘의 실행 옵션을 설정하는 명령임. 스크립트 초반에 `set -euo pipefail`을 넣으면 오류 처리 방식이 엄격해짐.

```bash id="cezj9l"
#!/usr/bin/env bash
set -euo pipefail

echo "스크립트 시작함"
```

## `set -e`

```bash id="lypx0k"
set -e
```

`set -e`는 명령이 실패하면 스크립트를 종료하게 함.

```bash id="d2qmol"
#!/usr/bin/env bash
set -e

cp source.txt backup.txt
echo "복사 완료함"
```

`cp source.txt backup.txt`가 실패하면 다음 줄의 `echo`까지 진행하지 않음.

`set -e`가 없으면 중간 명령이 실패해도 스크립트가 계속 실행될 수 있음.

```bash id="mwq7p5"
#!/usr/bin/env bash

cp source.txt backup.txt
echo "복사 실패 후에도 실행될 수 있음"
```

`set -e`는 실패한 상태로 다음 작업을 계속하지 않게 하기 위해 사용함.

## `set -u`

```bash id="qjcc1u"
set -u
```

`set -u`는 정의되지 않은 변수를 사용하면 오류로 처리함.

```bash id="vg86jr"
#!/usr/bin/env bash
set -u

echo "$NAME"
```

`NAME`이 정의되어 있지 않으면 스크립트가 실패함.

`set -u`가 없으면 정의되지 않은 변수가 빈 문자열처럼 처리되어 버그가 숨을 수 있음.

```bash id="femlg7"
#!/usr/bin/env bash

echo "배포 대상: $DEPLOY_TARGET"
```

`DEPLOY_TARGET` 오타나 누락이 있어도 빈 값으로 넘어갈 수 있음. `set -u`는 변수명 오타와 필수 환경변수 누락을 빨리 찾기 위해 사용함.

기본값이 필요한 변수는 아래처럼 처리함.

```bash id="3v1jwh"
#!/usr/bin/env bash
set -u

name="${NAME:-guest}"
echo "$name"
```

필수 변수는 아래처럼 검사함.

```bash id="hcc6vl"
#!/usr/bin/env bash
set -u

: "${TARGET_DIR:?TARGET_DIR가 필요함}"
echo "$TARGET_DIR"
```

## `set -o pipefail`

```bash id="b4q8xs"
set -o pipefail
```

`set -o pipefail`은 파이프라인 중간 명령의 실패도 전체 실패로 처리함.

```bash id="a4jhzf"
#!/usr/bin/env bash
set -o pipefail

grep "ERROR" app.log | sort | uniq
```

기본적으로 파이프라인은 마지막 명령의 종료 상태를 전체 종료 상태로 사용함.

```bash id="s1si7n"
#!/usr/bin/env bash

grep "ERROR" missing.log | sort
echo "성공처럼 이어질 수 있음"
```

위 경우 `grep`이 실패해도 마지막 명령인 `sort`가 성공하면 전체 파이프라인이 성공처럼 보일 수 있음.

`pipefail`을 켜면 파이프라인 안의 명령 중 하나라도 실패했을 때 전체 파이프라인이 실패로 처리됨.

```bash id="7ezx9g"
#!/usr/bin/env bash
set -o pipefail

grep "ERROR" missing.log | sort
echo "앞 명령 실패 시 실행되지 않음"
```

## `set -euo pipefail`

```bash id="3jxqlj"
set -euo pipefail
```

`set -euo pipefail`은 아래 세 설정을 한 번에 적용하는 형태임.

```bash id="nmqs0s"
set -e
set -u
set -o pipefail
```

| 옵션            | 의미                      |
| ------------- | ----------------------- |
| `-e`          | 명령 실패 시 스크립트를 종료함       |
| `-u`          | 정의되지 않은 변수 사용 시 오류로 처리함 |
| `-o pipefail` | 파이프라인 중간 실패를 전체 실패로 처리함 |

## 왜 필요한지

`set -euo pipefail`은 스크립트가 실패한 상태로 계속 진행되는 것을 막기 위해 필요함.

| 문제                         | 방지하는 설정    |
| -------------------------- | ---------- |
| 중간 명령이 실패했는데 다음 명령이 계속 실행됨 | `-e`       |
| 변수명 오타가 빈 문자열로 처리됨         | `-u`       |
| 파이프라인 앞쪽 명령 실패가 숨겨짐        | `pipefail` |

```bash id="x1dnsh"
#!/usr/bin/env bash
set -euo pipefail

src="${1:?원본 경로가 필요함}"
dst="${2:?대상 경로가 필요함}"

cp "$src" "$dst"
echo "복사 완료함"
```

이 스크립트는 인자가 없으면 바로 실패함. `cp`가 실패해도 바로 종료함. 실패한 상태로 다음 작업을 계속하지 않음.

## 주의할 점

`set -e`는 실패를 정상 흐름으로 사용하는 명령과 함께 쓸 때 조심해야 함.

```bash id="97aaim"
#!/usr/bin/env bash
set -euo pipefail

if grep -q "ERROR" app.log; then
  echo "에러가 있음"
else
  echo "에러가 없음"
fi
```

`if` 조건 안의 실패는 조건 판단으로 처리되므로 스크립트가 바로 종료되지 않음.

실패를 허용해야 하는 명령은 명시적으로 처리함.

```bash id="8i71x0"
#!/usr/bin/env bash
set -euo pipefail

grep "OPTIONAL" app.log || true
echo "OPTIONAL이 없어도 계속 진행함"
```

`|| true`는 해당 명령의 실패를 의도적으로 무시한다는 뜻임. 실패를 숨기므로 필요한 곳에만 사용함.

## 권장 기본 형태

```bash id="am38kb"
#!/usr/bin/env bash
set -euo pipefail

main() {
  echo "스크립트 시작함"
}

main "$@"
```

`main "$@"`는 스크립트로 들어온 인자를 `main` 함수에 그대로 전달함. 스크립트 본문과 실행 지점을 분리할 수 있어 구조가 명확해짐.

## 정리

`#!/bin/bash`는 `/bin/bash`에 있는 Bash로 실행함. `#!/usr/bin/env bash`는 `PATH`에서 Bash를 찾아 실행함. 파일을 `./script.sh`처럼 직접 실행할 때 shebang이 적용됨. `bash script.sh`처럼 실행하면 명령어로 지정한 Bash가 사용됨.

`set -euo pipefail`은 안전한 Bash 스크립트를 만들기 위한 기본 설정임. `-e`는 실패 시 종료함. `-u`는 정의되지 않은 변수를 오류로 처리함. `pipefail`은 파이프라인 실패를 숨기지 않음. 빌드, 배포, 백업, 파일 처리처럼 실패가 치명적인 스크립트에서는 기본으로 넣는 편이 좋음.
