# godotpractice プロジェクト計画

既存ゲーム 9 本を題材に Godot 4.7 でゲームを作り、その過程で Godot 開発の skill・ツール・知見を bannzai/castle に蓄積する学習プロジェクト。本ドキュメントは確定した目的・対象・運用・技術構成の SSOT。起点は https://github.com/bannzai/godotpractice/issues/1 。

## 目的

ゲームを完成させること自体より、次を得ることが目的 (issue #1)。各ゲームの作業者は、実装しながらこれらに当たる知見を `documents/knowledge/<slug>.md` に残す。

- skill・script の拡充 (godot-development / game-asset-search / webtunnel 等の改善点)
- 開発に必要なツールの用意
- Godot の知見 (ハマりどころ・回避策・設計パターン)
- アセットの効率的な準備 (フリー素材の検索・生成・クレジット記録)
- 品質を高める運用 (AI が動作確認・文章確認を繰り返し行う。アニメーションの検証も行う)
- 市場調査・ジャンル検索・競合調査 (Steam を想定)
- Codex App Server を利用した効率的なアセット管理・作成、bannzai の Godot の理解・学習

## 対象ゲーム

1 ゲーム = `games/<slug>/` の 1 Godot プロジェクト = 1 worktree (ブランチ `game/<slug>`) = 1 作業者。作業者に渡すのは「作って欲しいゲーム」(元ネタとジャンル) だけで、issue に書かれた受け入れ条件・見た目の基準・検証方法は配らない (配った結果、全ゲームの画面構成が同じになった。PR #87 以降の運用)。

| slug | 元ネタ (名称・素材は使わない) | ジャンル | 次元 | issue |
| --- | --- | --- | --- | --- |
| monsterquest | ポケットモンスター赤 | モンスター収集 RPG | 2D | #2 |
| platformer | スーパーマリオブラザーズ | 横スクロールアクション | 2D | #3 |
| fighter | ストリートファイター | 2D 対戦格闘 | 2D | #4 |
| shooter | (オーソドックスな縦 STG) | シューティング | 2D | #5 |
| deckrogue | Slay the Spire | デッキ構築ローグライク | 2D | #6 |
| survivors | Vampire Survivors | サバイバーアクション | 2D | #7 |
| cardbattle | 遊戯王 | TCG 対 CPU 決闘 | 2D | #8 |
| rollball | 塊魂 | 巻き込み 3D アクション | 3D | #9 |
| crewrts | ピクミン | 仲間を率いる 3D アクション RTS | 3D | #10 |

品質の基準 (issue #1 の原文): 「クオリティについては画像や BGM・SE も使ってゲームとして成立するようにしてください。なお、素材部分についてはそれっぽければ良くて完コピじゃなくていいです」。画面構成 (タイトル → プレイ → 結果など) は指定しない。

## 運用

- **司令塔**: tmux セッション `godotpractice` の window 0 で動く Claude Code (Fable)。各 worktree の進捗を `tmux capture-pane` で監視し、必要なら `tmux send-keys` で介入する。`documents/knowledge/*.md` に溜まった知見をまとめて bannzai/castle に issue として起票する (skill・rules・ツールへの反映は castle 側で行う)
- **作業者**: 各 worktree で動く Codex CLI (GPT-6 Astra)。`tmux-branch-setup --codex game/<slug>` で起動し、作って欲しいゲームだけを渡す。画面構成・見た目・検証方法は作業者がゲームごとに決める
- **ブランチと PR**: 作業者は `game/<slug>` にこまめに commit・push し、早い段階で draft PR を作って進捗を反映する。受け入れ条件を満たしたら ready for review にする。PR のマージは司令塔またはユーザーが行い、作業者は行わない
- **変更範囲**: 作業者は `games/<slug>/` と `documents/knowledge/<slug>.md` の外を変更しない (ルートの AGENTS.md・Makefile・`.github/`・他のゲームは共有物で、司令塔が別 PR で変える)。ゲーム間でファイルが重ならないため、worktree 間の衝突は起きない
- **知見の流れ**: 作業者 → `documents/knowledge/<slug>.md` (ゲームの PR に含める) → 司令塔が横断して読み、castle の issue へ (skill の改善・rules の追加・ツールの新設)。godot-development skill の `references/pitfalls.md` が Godot のハマりどころの集約先
- **安全**: リポジトリは public。秘匿情報 (トークン・API キー・個人情報) をコミット・ログ・PR に載せない。PC に危害が加わる操作 (リポジトリ外の削除・システム設定の変更・`--yolo` 相当の起動) を行わない。force push・履歴の書き換え・PR のマージを作業者は行わない
- **リリース**: 本プロジェクトでは行わない (Steam への提出・Steamworks 連携はスコープ外)

## 技術構成 (インフラ決定の記録)

| 項目 | 決定 | 理由 |
| --- | --- | --- |
| エンジン | Godot 4.7 stable + GDScript (全ゲーム共通) | 詳細は [ADR 0001](adr/0001-godot-gdscript-monorepo-unpublished.md) |
| レンダラ | GL Compatibility (3D のゲームも) | CI の Xvfb + Mesa llvmpipe と Web エクスポート (WebGL 2) の両方で描画できる。Forward+ は Vulkan 前提でソフトウェア GL で動かない |
| リポジトリ構成 | モノレポ。`games/<slug>/` に独立した Godot プロジェクト、ルートに共有物 (AGENTS.md・Makefile・CI・rules・documents) | 1 リポジトリで worktree を並べ、知見を 1 箇所 (`documents/knowledge/`) に集める。ゲームごとにファイルが分かれるため並列作業で衝突しない |
| 配布ターゲット | Windows (x86_64) / macOS (universal) / Linux (x86_64) のデスクトップエクスポート + 動作確認専用の Web エクスポート | Steam 向けの構成を素振りする。Web は webtunnel での動作確認にだけ使う |
| 検証 | 作業者がゲームごとに決める (共通の Makefile target・雛形は配らない)。ルートの Makefile は `make list` と `make <slug>-run` の委譲だけを提供する | 共通の検証手順を配ると作り方まで揃ってしまう (PR #87 の経緯) |
| CI・コードレビュー | 行わない。PR は CI の結果やレビューを待たずにマージする | ユーザーの指示 (2026-09-07)。`.github/workflows/` の CI は残っているが結果を待たない |
| GHA 上の動作確認 | CI の `screenshot-and-movie` job (Xvfb + llvmpipe。撮影と録画の artifact) と、webtunnel の caller workflow (`browser-session.yml`。Web エクスポートを runner 上の Chromium で開く) | 調査 https://github.com/bannzai/castle/issues/891 で 3 経路とも成立を実測済み。webtunnel 経路の前提は下記「未検証事項」 |
| 素材 | フリー素材 (CC0 優先) と生成物。原作素材は使わない。記録は各ゲームの `assets/CREDITS.md` | public リポジトリで商標・著作権の問題を作らない。探し方・生成・記録は game-asset-search skill |
| Steamworks / ストア / 課金 / 法務 | 対象外 | リリースしない (issue #1) |

## 未検証事項・リスク

- **webtunnel 経由の動作確認**は 2026-09-06 に実セッションで成立を確認した (Secrets の登録と webtunnel の `software_webgl` input https://github.com/bannzai/webtunnel/issues/22 の両方が揃った)。runner の Chromium は SwiftShader (`ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero)))`) で WebGL 2 が有効になり、Godot 既定シェルの起動判定 (`#status` の消滅) が true、ビューポートは 1280x656 (ゲーム座標のスケール 0.911)。手順は [AGENTS.md](../AGENTS.md)「検証方法」。SwiftShader は CPU 描画のため fps に依存する検証には向かない
- **CI の変更ゲーム判定** (`.github/scripts/changed-games.sh`) は、`games/` だけを変えた PR で初めて絞り込みが働く。共有物を含む最初の PR では全ゲームが対象になるため、絞り込みの動作は最初のゲーム PR で確認する
- **3D ゲーム (rollball / crewrts) の llvmpipe 描画**は遅い。`screenshot-and-movie` job の timeout を 45 分にしてあるが、シーンが重くなったら `MOVIE_FRAMES` を減らすか撮影対象を絞る
- **Codex (GPT-6 Astra) のレート制限**: 5 時間あたりのメッセージ枠が小さく、9 worktree を同時に走らせると枠を早く消費する。作業者の起動は枠の残量を見て段階的に行う
- **godot-development skill のローカル配置**: castle の checkout が別ブランチで作業中のため、`~/.agents/skills/godot-development` がローカルに無い期間がある。作業者は AGENTS.md に書いた GitHub 上の同 skill を参照する (ユーザー作業 #11)
