# 第二回レポート課題(10/19出題，10/25解答)
## 課題内容(マルチプルテーブルを読む)
OpenFlow1.3 版スイッチの動作を説明せよ．

スイッチ動作の各ステップについて，
trema dump_flows の出力 (マルチプルテーブルの内容) を混じえながら動作を説明すること．

## 解答
以下の動作に関する説明を行う．

・初期化

・PacketIn時の動作(host1からhost2へのパケットの送信)

・FlowMod時の動作(host2からhost1へのパケットの送信)

・PacketInが生じないときの動作(host2からhost1へのパケットの送信)

・FlowModによって新たにエントリを追加してから180秒後の動作

### 初期化について
スイッチがコントローラに接続されると，switch_ready関数が呼び出され，フローテーブルの初期化が行われる．
初期化後のフローテーブルの内容を以下に示す．
```
$ ./bin/trema dump_flows lsw
cookie=0x0, duration=27.564s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=01:00:00:00:00:00/ff:00:00:00:00:00 actions=drop #フローエントリ1
cookie=0x0, duration=27.527s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=33:33:00:00:00:00/ff:ff:00:00:00:00 actions=drop #フローエントリ2
cookie=0x0, duration=27.527s, table=0, n_packets=0, n_bytes=0, priority=1 actions=goto_table:1 #フローエントリ3
cookie=0x0, duration=27.527s, table=1, n_packets=0, n_bytes=0, priority=3,dl_dst=ff:ff:ff:ff:ff:ff actions=FLOOD #フローエントリ4
cookie=0x0, duration=27.527s, table=1, n_packets=0, n_bytes=0, priority=1 actions=CONTROLLER:65535 #フローエントリ5
```
フローエントリ1〜3はフィルタリングテーブルのフローエントリで，フローエントリ4〜5は転送テーブル(ID = 1)のフローエントリである．
各フローエントリの内容について説明する．

・フローエントリ1 (優先度2):

宛先MACアドレスがマルチキャストアドレス(01:00:00:00:00:00，ff:00:00:00:00:00)である場合，パケットをドロップする．

・フローエントリ2 (優先度2):

宛先MACアドレスがipv6マルチキャストアドレス(33:33:00:00:00:00，ff:ff:00:00:00:00)である場合，パケットをドロップする．

・フローエントリ3 (優先度1):

転送テーブル(ID = 1)へ移行する．

・フローエントリ4 (優先度3):

宛先MACアドレスが，ブロードキャストアドレス(ff:ff:ff:ff:ff:ff)である場合，パケットをフラッディングする．

・フローエントリ5 (優先度1):

コントローラにPacketInを送信する．

### PacketIn時の動作について
PacketIn時の動作を再現するために，host1からhost2へのパケットの送信を行った．
パケット送信後のフローテーブルの内容を以下に示す．
```
$ ./bin/trema send_packets --source host1 --dest host2
$ ./bin/trema dump_flows lsw
cookie=0x0, duration=785.753s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=01:00:00:00:00:00/ff:00:00:00:00:00 actions=drop #フローエントリ1
cookie=0x0, duration=785.716s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=33:33:00:00:00:00/ff:ff:00:00:00:00 actions=drop #フローエントリ2
cookie=0x0, duration=785.716s, table=0, n_packets=1, n_bytes=42, priority=1 actions=goto_table:1 #フローエントリ3
cookie=0x0, duration=785.716s, table=1, n_packets=0, n_bytes=0, priority=3,dl_dst=ff:ff:ff:ff:ff:ff actions=FLOOD #フローエントリ4
cookie=0x0, duration=785.716s, table=1, n_packets=1, n_bytes=42, priority=1 actions=CONTROLLER:65535 #フローエントリ5
```
フローエントリ3によって，転送テーブル(ID = 1)へ移行後，
転送テーブルのフローエントリ5が適用され，PacketInが生じる．
エントリが適用されたパケット数を表す，n_packetsの項目を見ると，n_packets=1となっており，
フローエントリ3とフローエントリ5が適用されたことがわかる．
なお，フローテーブルのフローエントリの追加や削除は行われないが，PacketInにより，コントローラのFDBは更新される．

### FlowMod時の動作について
FlowMod時の動作を再現するために，host1からhost2へのパケットの送信後に，
host2からhost1へのパケットの送信を行った．
パケット送信後のフローテーブルの内容を以下に示す．
```
$ ./bin/trema send_packets --source host1 --dest host2
$ ./bin/trema send_packets --source host2 --dest host1
$ ./bin/trema dump_flows lsw
cookie=0x0, duration=14.312s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=01:00:00:00:00:00/ff:00:00:00:00:00 actions=drop #フローエントリ1
cookie=0x0, duration=14.272s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=33:33:00:00:00:00/ff:ff:00:00:00:00 actions=drop #フローエントリ2
cookie=0x0, duration=14.272s, table=0, n_packets=2, n_bytes=84, priority=1 actions=goto_table:1 #フローエントリ3
cookie=0x0, duration=14.272s, table=1, n_packets=0, n_bytes=0, priority=3,dl_dst=ff:ff:ff:ff:ff:ff actions=FLOOD #フローエントリ4
cookie=0x0, duration=3.078s, table=1, n_packets=0, n_bytes=0, idle_timeout=180, priority=2,in_port=2,dl_src=3a:07:89:26:92:3b,dl_dst=d6:aa:86:c7:58:85 actions=output:1 #フローエントリ5
cookie=0x0, duration=14.272s, table=1, n_packets=2, n_bytes=84, priority=1 actions=CONTROLLER:65535 #フローエントリ6
```
フローエントリ3とフローエントリ6のn_packetsの値がn_packets=2となっていることから，
host1からhost2へのパケットの送信時と，host2からhost1へのパケットの送信時ともに，フローエントリ3によって，転送テーブルへ移行後，
フローエントリ6が適用され，PacketInが生じていることがわかる．
また，host2からhost1へのパケットの送信時，FlowModが発生し，転送テーブル(ID = 1)にフローエントリ5が追加されている．
フローエントリ5は送信元のポート番号が2のとき，ポート1へパケットを出力する内容になっており，
優先度は2，エントリの破棄までの時間は180秒となっている．

### PacketInが生じないときの動作
PacketInが生じないときの動作を再現するために，host1からhost2へのパケットを送信後に，
host2からhost1へのパケットの送信を行い，再度，host2からhost1へのパケットの送信を行った．
以上の操作を行った後のフローテーブルの内容を以下に示す．
```
$ ./bin/trema send_packets --source host1 --dest host2
$ ./bin/trema send_packets --source host2 --dest host1
$ ./bin/trema dump_flows lsw
cookie=0x0, duration=38.498s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=01:00:00:00:00:00/ff:00:00:00:00:00 actions=drop
cookie=0x0, duration=38.459s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=33:33:00:00:00:00/ff:ff:00:00:00:00 actions=drop
cookie=0x0, duration=38.459s, table=0, n_packets=2, n_bytes=84, priority=1 actions=goto_table:1
cookie=0x0, duration=38.459s, table=1, n_packets=0, n_bytes=0, priority=3,dl_dst=ff:ff:ff:ff:ff:ff actions=FLOOD
cookie=0x0, duration=2.431s, table=1, n_packets=0, n_bytes=0, idle_timeout=180, priority=2,in_port=2,dl_src=4d:a1:9a:ba:dd:fc,dl_dst=d7:2b:1e:c8:7e:e3 actions=output:1
cookie=0x0, duration=38.459s, table=1, n_packets=2, n_bytes=84, priority=1 actions=CONTROLLER:65535
$ ./bin/trema send_packets --source host2 --dest host1
$ ./bin/trema dump_flows lsw
cookie=0x0, duration=14.722s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=01:00:00:00:00:00/ff:00:00:00:00:00 actions=drop #フローエントリ1
cookie=0x0, duration=14.682s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=33:33:00:00:00:00/ff:ff:00:00:00:00 actions=drop #フローエントリ2
cookie=0x0, duration=14.682s, table=0, n_packets=3, n_bytes=126, priority=1 actions=goto_table:1 #フローエントリ3
cookie=0x0, duration=14.682s, table=1, n_packets=0, n_bytes=0, priority=3,dl_dst=ff:ff:ff:ff:ff:ff actions=FLOOD #フローエントリ4
cookie=0x0, duration=6.135s, table=1, n_packets=1, n_bytes=42, idle_timeout=180, priority=2,in_port=2,dl_src=a5:d7:1d:59:53:f1,dl_dst=dc:60:9d:73:42:ad actions=output:1 #フローエントリ5
cookie=0x0, duration=14.682s, table=1, n_packets=2, n_bytes=84, priority=1 actions=CONTROLLER:65535 #フローエントリ6
```
1度目のhost2からhost1へのパケット送信後のテーブルと2度目の送信後のテーブルのn_packetsの値を比較すると，
2度目の送信時には，フローエントリ3と，フローエントリ5が適用されていることがわかる．
2度目の送信時では，フローエントリ3によって，転送テーブル(ID = 1)に移行後，1度目の送信時のFlowModによって新たに追加されたフローエントリ5が
適用され，PacketInは生じず，新たに追加されたフローエントリ5を活用して，パケットの送受信が行われる．

### FlowModから180秒後の動作について
FlowMod時に新たに追加されるエントリの破棄までの時間は180秒に設定されている．
この動作を再現するために，host1からhost2へのパケットを送信後に，
host2からhost1へのパケットの送信を行い，180秒待った後に
テーブルの内容を出力した．
結果を以下に示す．
```
$ ./bin/trema send_packets --source host1 --dest host2
$ ./bin/trema send_packets --source host2 --dest host1
$ ./bin/trema dump_flows lsw
cookie=0x0, duration=11.71s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=01:00:00:00:00:00/ff:00:00:00:00:00 actions=drop #フローエントリ1
cookie=0x0, duration=11.672s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=33:33:00:00:00:00/ff:ff:00:00:00:00 actions=drop #フローエントリ2
cookie=0x0, duration=11.662s, table=0, n_packets=2, n_bytes=84, priority=1 actions=goto_table:1 #フローエントリ3
cookie=0x0, duration=11.672s, table=1, n_packets=0, n_bytes=0, priority=3,dl_dst=ff:ff:ff:ff:ff:ff actions=FLOOD #フローエントリ4
cookie=0x0, duration=3.133s, table=1, n_packets=0, n_bytes=0, idle_timeout=180, priority=2,in_port=2,dl_src=52:41:98:55:0c:af,dl_dst=eb:72:39:4d:82:6f actions=output:1 #フローエントリ5
cookie=0x0, duration=11.666s, table=1, n_packets=2, n_bytes=84, priority=1 actions=CONTROLLER:65535 #フローエントリ6
# 180秒待つ
$ ./bin/trema dump_flows lsw
cookie=0x0, duration=227.918s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=01:00:00:00:00:00/ff:00:00:00:00:00 actions=drop
cookie=0x0, duration=227.88s, table=0, n_packets=0, n_bytes=0, priority=2,dl_dst=33:33:00:00:00:00/ff:ff:00:00:00:00 actions=drop
cookie=0x0, duration=227.87s, table=0, n_packets=2, n_bytes=84, priority=1 actions=goto_table:1
cookie=0x0, duration=227.88s, table=1, n_packets=0, n_bytes=0, priority=3,dl_dst=ff:ff:ff:ff:ff:ff actions=FLOOD
cookie=0x0, duration=227.874s, table=1, n_packets=2, n_bytes=84, priority=1 actions=CONTROLLER:65535
```
host2からhost1へのパケットの送信直後のテーブルの内容と，180後のテーブルの内容を比較すると，フローエントリ5が削除されていることがわかり，
idle_timeoutが設定されているエントリは，設定時間後にエントリが破棄されることを確認した．