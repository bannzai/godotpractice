# 0001. Godot 4.7 + GDScript のモノレポで 9 ゲームを作り、Steam へは公開しない

## Status

Accepted

## Context

既存ゲーム 9 本 (RPG・横スクロール・格闘・STG・デッキ構築ローグライク・サバイバー・TCG・3D 巻き込み・3D RTS) を題材に、Godot でゲームを作りながら skill・ツール・知見を bannzai/castle に蓄積する ( https://github.com/bannzai/godotpractice/issues/1 )。各ゲームは worktree を分けて Codex の作業者が並列に作り、window 0 の Claude Code が監視する。

制約:

- 想定プラットフォームは Steam だが、本プロジェクトではリリースしない。Steamworks パートナー登録・SDK 連携は行わない
- リポジトリは public。元ネタの名称・画像・音・ロゴは商標・著作権のため使えない
- 先行の素振り bannzai/suicagamecopy (Godot 4.7 + GDScript・GL Compatibility・デスクトップ 3 種エクスポート・CI 全 pass) の構成と、それを雛形化した godot-development skill を流用できる
- 動作確認は GHA 上 (CI の Xvfb 撮影・録画、webtunnel) で行いたい。ローカルマシンの資源を 9 ゲーム分の描画に使わない

## Decision

- エンジンは Godot 4.7 stable、言語は GDScript を全ゲーム共通で採用する (C# は導入しない。.NET 版はエクスポートと CI のセットアップが増え、本プロジェクトで C# を要する理由がない)
- レンダラは 3D のゲームを含めて GL Compatibility にする。CI の Xvfb + Mesa llvmpipe と Web エクスポート (WebGL 2) の両方で描画でき、GHA 上の動作確認が成立する。Forward+ の機能 (Vulkan 前提) は使わない
- リポジトリはモノレポにする。`games/<slug>/` に独立した Godot プロジェクトを置き、ルートに共有物 (AGENTS.md・Makefile・CI・`.claude/rules`・`documents/`) を置く。1 ゲーム = 1 worktree = 1 作業者で、作業者は自分の `games/<slug>/` と `documents/knowledge/<slug>.md` の外を変更しない。9 リポジトリに分けると知見の集約先と CI・rules の同期が 9 倍になるため採らない
- 「Steam 向け」はデスクトップ 3 プラットフォーム (Windows x86_64 / macOS universal / Linux x86_64) へのエクスポート構成を持つことと定義し、Steamworks SDK (GodotSteam 等) の連携は行わない。加えて動作確認専用の Web エクスポートを持つ (webtunnel で開くため。配布はしない)
- 元ネタの名称・素材は使わない。作業名は一般名詞の slug (monsterquest / platformer / fighter / shooter / deckrogue / survivors / cardbattle / rollball / crewrts) にし、素材はフリー素材 (CC0 優先) と生成物に限って各ゲームの `assets/CREDITS.md` に記録する
- 公開しないため、法務ドキュメント・LP・ストア素材・課金・通知基盤は整備しない

## Consequences

- 良い点: 9 ゲームが同じ検証手順 (Makefile の target・CI の matrix) で回り、ハマりどころと素材準備の知見が `documents/knowledge/` に集まる。Linux ランナーだけで CI が完結する。作業者間でファイルが重ならず、worktree の並列作業で衝突しない
- 悪い点: GL Compatibility では 3D の表現 (高度なライティング・ポストエフェクト) が制限される。Steam 固有機能 (実績・オーバーレイ・クラウドセーブ・Steam Input) の素振りはできない。macOS の署名・公証は未検証のまま残る。CI は PR ごとに変更ゲームだけを回すが、共有物を変えると 9 ゲーム分が走る
- エージェントへの制約: C# を導入しない。Steamworks SDK / GodotSteam を追加しない。元ネタの名称・素材を追加しない。レンダラを GL Compatibility から変えない。`games/<slug>/` の外の共有物は司令塔が別 PR で変える (根拠は本 ADR)。公開する判断が出た場合は create-new-app skill の Phase 5 (法務・LP) と Phase 8 (ストア素材) を実施し、本 ADR を Superseded にする
