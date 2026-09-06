# 知見の置き場

各ゲームの作業者が、実装中に得た知見を `documents/knowledge/<slug>.md` に追記する (slug は `games/<slug>/` と同じ。ファイルはゲームごとに分けて worktree 間の衝突を避ける)。司令塔 (window 0 の Claude Code) が横断して読み、bannzai/castle の issue (skill の改善・rules の追加・ツールの新設) に起票する。目的の一覧は [PROJECT.md](../PROJECT.md)「目的」。

書く内容 (1 項目 = 見出し 1 つ。出典やコマンド・commit を添える):

- Godot のハマりどころと回避策 (godot-development skill の `references/pitfalls.md` に載っていないもの)
- 素材の準備で効いた方法・使えなかった素材源とその理由 (game-asset-search skill への改善点)
- 動作確認・アニメーション検証で効いた方法 (screenshot.gd の書き方、selfcheck の切り方、CI artifact の見方)
- ジャンル固有の設計判断 (状態管理・データ定義・物理の使い方)
- 共有物 (AGENTS.md・Makefile・CI・rules) への変更提案 (作業者は共有物を直接変えないため、ここに書いて司令塔が反映する)
- skill・ツールとして切り出せそうな手順
