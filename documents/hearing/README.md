# 作業者へのヒアリング (2026-09-06)

9 ゲームの実装を終えた Codex (GPT-6 Astra) の作業者に、司令塔 (window 0 の Claude Code) が同じ 6 項目で行ったヒアリングの回答をそのまま置く (ファイル名は `games/<slug>` の slug)。castle への issue 起票の一次資料で、内容は各作業者の自己申告 (司令塔は PR の差分・CI・画像で検証したが、回答の全項目を再実行して確かめたわけではない)。

質問項目:

1. 開発の進め方 (どの順で何を作ったか、詰まった点とどう解決したか)
2. 使ったツール・skill・コマンド
3. 欲しかったが無かったツール・skill・スクリプト
4. 素材 (画像・BGM・SE・フォント) の準備方法と、素材源・生成手段ごとの使い勝手
5. 動作確認の方法 (headless の selfcheck・screenshot.gd・movie・CI artifact・webtunnel のうち何を使い、何が効いて何が足りなかったか。アニメーションの検証)
6. Godot 固有のハマりどころと回避策

起票した castle の issue は [PROJECT.md](../PROJECT.md)「知見の流れ」の運用に従い、各 issue から本ディレクトリを参照する。
