# Retro Diffusion 시안 프롬프트 (세계 1: 태양 폭풍)

## 목적
게임 화면의 **분위기와 화풍을 정하기 위한 시안**이다. 마음에 드는 것을 골라 알려 주면, 그 팔레트와 분위기에 맞춰 게임 쪽(타일·캐릭터·조명)을 맞춘다.

## 진행 방법
1. https://retrodiffusion.ai 에 가입한다. 새 계정은 **$0.50 무료 크레딧**(카드 불필요)이다.
2. 모델은 **RD Lite($0.05/장)**로 시안을 뽑는다. 아래 8개를 모두 뽑아도 약 $0.41이라 무료 크레딧 안이다. **무료 크레딧을 넘겨서 결제하지는 않는다**(과제의 유료 AI 사용 제한 때문에).
3. 생성한 이미지를 `game/art/concepts/`에 아래 **파일 이름**으로 저장하고 알려 준다.
4. 약관(Terms)에서 생성물의 상업적 사용·소유권 조항을 직접 한 번 확인한다. (가격 페이지에는 적혀 있지 않았다)
5. 같은 프롬프트로 몇 번 돌려 가장 마음에 드는 한 장만 남겨도 된다. 크레딧이 모자라면 우선순위 1~3번(배경)부터.

## 모든 프롬프트 끝에 붙이는 공통 문장
```
side-view 2D pixel art, limited palette, clean pixel grid, no anti-aliasing, melancholy atmosphere, soft lighting, no text, no UI
```

## 프롬프트

| 우선순위 | 파일 이름 | 크기 | 프롬프트 (공통 문장 앞부분) |
|---|---|---|---|
| 1 | `bg_street_dusk.png` | 480x270 | `ruined city street at dusk, dead traffic lights, burnt-out power lines hanging, hazy orange sky from a solar flare, abandoned stalled cars, silhouetted buildings in the distance, empty road, parallax background, no characters` |
| 2 | `bg_street_cold.png` | 480x270 | `ruined city street at night after a solar storm, cold desaturated blue-grey palette, faint green aurora in the sky, dead traffic lights, silhouetted skyline, stalled cars, hanging power lines, parallax background, no characters` |
| 3 | `bg_hospital.png` | 480x270 | `abandoned hospital interior, dark corridor with dead ceiling lights, thin window light from one side, scattered papers on the floor, emergency generator in the distance, side-view room background, no characters` |
| 4 | `tiles_world1.png` | 타일셋(Tileset) 기능, 16x16 | `cracked asphalt, concrete wall, scorched metal panels, hospital corridor floor tiles, exposed wires` |
| 5 | `player_concept.png` | 32x32 스프라이트 | `small office worker in a plain grey jacket with an ID badge on a lanyard, gender-neutral, short hair, tired posture, standing idle, side view, transparent background` |
| 6 | `enemy_guard_robot.png` | 32x32 스프라이트 | `broken security patrol robot, bulky rusted body, one claw arm raised, flickering red sensor eye, sparks, side view, transparent background` |
| 7 | `props_device.png` | 소품 시트 | `set of small props: sparking severed power cable, wooden ladder, hand-crank lift platform, electric sliding door, lever switch, 16x16 each, transparent background` |
| 8 | `title_bg.png` | 480x270 | `a tiny lone figure standing before a vast silent ruined city skyline under a dim sun, huge empty space, little nightmares mood, dark silhouettes with a single warm light, no characters other than the tiny figure` |

## 참고(게임 쪽 규격)
- 게임 화면은 **480x270**을 3배(1440x810)로 확대한다. 한 칸은 **16픽셀**.
- 플레이어는 약 10x22픽셀(스프라이트는 16x24 정도), 경비 로봇은 약 16x20픽셀이다. 캐릭터 시안은 크게 뽑아도 되고, 게임에 넣을 때 제가 줄이고 팔레트를 맞춘다.
- AI 생성물은 칸에 정확히 맞지 않는 경우가 많다. 그래서 **배경과 분위기 기준**으로만 쓰고, 타일·캐릭터·장치는 시안을 참고해 직접 도트로 그린다(하이브리드).
