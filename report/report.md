# 第二回レポート課題(10/12出題，10/18解答)
## 課題内容(複数スイッチ対応版 ラーニングスイッチ)
複数スイッチに対応したラーニングスイッチ (multi_learning_switch.rb) の動作を説明せよ．

* 複数スイッチの FDB をどのように実現しているか、コードと動作を解説する
* 動作の様子やフローテーブルの内容もステップごとに確認すること
* 必要に応じて図解すること
## 解答
###ソースコードの解説
####コントローラの起動，スイッチの接続について
コントローラ起動時に呼び出されるstartメソッドと，スイッチの接続時に
呼び出されるswitch_readyメソッドのコードを以下に示す．
```ruby
 9  def start(_argv)
10    @fdbs = {}
11    logger.info 'MultiLearningSwitch started.'
12  end
13
14  def switch_ready(datapath_id)
15    @fdbs[datapath_id] = FDB.new
16  end
```
複数スイッチに対応するために，startメソッドでは，複数のFDBを管理するための
連想配列の初期化を行っている(10行目)．
swich_readメソッドでは，新たに接続されたスイッチのFDBを生成し，datapath_idをキーとし，
連想配列へ格納している(15行目)．

####PacketInの処理について
PacketInが発生した際に呼び出されるpacket_inメソッドのコードを以下に示す．
```ruby
18  def packet_in(datapath_id, message)
19    return if message.destination_mac.reserved?
20    @fdbs.fetch(datapath_id).learn(message.source_mac, message.in_port)
21    flow_mod_and_packet_out message
22  end
```
fetchメソッドを用いて，PacketInの対象となるスイッチのFDBオブジェクトを取得し，
学習を行い，FDBを更新する(20行目)．
そして，flow_mod_and_packet_outメソッドを呼び出す．

####FlowMod，PacketOutの制御について
FlowMod，PacketOutの制御を行うflow_mod_and_packet_outメソッドのコードを以下に示す．
```ruby
30  def flow_mod_and_packet_out(message)
31    port_no = @fdbs.fetch(message.dpid).lookup(message.destination_mac)
32    flow_mod(message, port_no) if port_no
33    packet_out(message, port_no || :flood)
34  end
```
PacketInの対象となるスイッチのFDBに，PacketInメッセージの宛先MACアドレスとポート番号が
登録されているかを確認する(31行目)．
宛先MACアドレスとそれに対応するポート番号がFDBに登録されている場合，flow_modメソッドを
呼び出し，FlowModの処理を行う(32行目)．
最後に，宛先MACアドレスがFDBに登録されているかどうかに関わらず，packet_outメソッドを
呼び出し，PacketOutの処理を行う(33行目)．
このとき，宛先MACアドレスとそれに対応するポート番号がFDBに登録されていない場合は，
PacketOutメッセージをフラッディングで出力するように，オプションを指定する．
flow_modメソッド，packet_outメソッドについては，特筆すべき変更点がないので，
説明は省略する．

###ラーニングスイッチの動作の解説
2つのスイッチが存在する環境における，ラーニングスイッチの動作の解説を行う．
動作環境の設定ファイル(trema.multi.conf)の内容と概念図を以下に示す．
```
vswitch('lsw1') { datapath_id 0x1 }
vswitch('lsw2') { datapath_id 0x2 }

vhost('host1')
vhost('host2')
vhost('host3')
vhost('host4')

link 'lsw1', 'host1'
link 'lsw1', 'host2'
link 'lsw2', 'host3'
link 'lsw2', 'host4'
```

![fig1](https://github.com/handai-trema/learning-switch-nsyuyu/blob/master/fig1.jpg)

また，動作手順を以下に記す．

1. host1からhost2へパケットを送信する．
2. host2からhost1へパケットを送信する．
3. host1からhost2へパケットを送信する．
4. host3からhost4へパケットを送信する．
5. host4からhost3へパケットを送信する．
6. host3からhost4へパケットを送信する．
7. host1からhost3へパケットを送信する．

以下，各手順におけるラーニングスイッチの動作を解説する．

#### 手順1 host1からhost2へパケットを送信する際の動作
パケットを受信したlsw1は，FlowTableにパケットが登録されていないため，
コントローラへPacketInを送信する．
PacketInを受信したコントローラは，lsw1のFDB(FDB1)を更新し，
フラッディングモードを指定したPacketOutをlsw1へ送信する．
以下の図に手順1の一連の動作を示す．

![fig2](https://github.com/handai-trema/learning-switch-nsyuyu/blob/master/fig2.jpg)

また，動作結果を以下に示す．
```
$ ./bin/trema send_packets --source host1 --dest host2
$ ./bin/trema show_stats host1
Packets sent:
  192.168.0.1 -> 192.168.0.2 = 1 packet
$ ./bin/trema show_stats host2
Packets received:
  192.168.0.1 -> 192.168.0.2 = 1 packet
```
上記の結果より，host1からhost2へ正しくパケットが送信されたことがわかる．

#### 手順2 host2からhost1へパケットを送信する際の動作
パケットを受信したlsw1は，FlowTableにパケットが登録されていないため，
コントローラへPackatInを送信する．
PacketInを受信したコントローラは，lsw1のFDB(FDB1)を更新する．
host1に対応するポート番号がFDB1に登録されており，出力先のポート番号が
決定できるため，コントローラはlsw1に対して，FlowModメッセージを送信し，
host2からhost1へのパケットのフローエントリをFlowTableに書き込む．
その後，コントローラはlsw1に対して，出力先のポート番号を指定した
PacketOutメッセージを送信する．
以下の図に手順2の一連の動作を示す．

![fig3](https://github.com/handai-trema/learning-switch-nsyuyu/blob/master/fig3.jpg)

また，動作結果を以下に示す．
```
$ ./bin/trema send_packets --source host2 --dest host1
$ ./bin/trema show_stats host1
Packets sent:
  192.168.0.1 -> 192.168.0.2 = 1 packet
Packets received:
  192.168.0.2 -> 192.168.0.1 = 1 packet
$ ./bin/trema show_stats host2
Packets sent:
  192.168.0.2 -> 192.168.0.1 = 1 packet
Packets received:
  192.168.0.1 -> 192.168.0.2 = 1 packet
```
上記の結果より，host2からhost1へ正しくパケットが送信され，FlowTableも
更新されていることがわかる．

#### 手順3 host1からhost2へパケットを再度送信する際の動作
パケットを受信したlsw1は，FlowTableにパケットが登録されていないため，
コントローラへPackatInを送信する．
host2に対応するポート番号がFDB1に登録されており，出力先のポート番号が
決定できるため，コントローラはlsw1に対して，FlowModメッセージを送信し，
host1からhost2へのパケットのフローエントリをFlowTableに書き込む．
その後，コントローラはlsw1に対して，出力先のポート番号を指定した
PacketOutメッセージを送信する．
以下の図に手順3の一連の動作を示す．

![fig4](https://github.com/handai-trema/learning-switch-nsyuyu/blob/master/fig4.jpg)

また，動作結果を以下に示す．
```
$ ./bin/trema send_packets --source host1 --dest host2
$ ./bin/trema show_stats host1
Packets sent:
  192.168.0.1 -> 192.168.0.2 = 2 packets
Packets received:
  192.168.0.2 -> 192.168.0.1 = 1 packet
$ ./bin/trema show_stats host2
Packets sent:
  192.168.0.2 -> 192.168.0.1 = 1 packet
Packets received:
  192.168.0.1 -> 192.168.0.2 = 2 packets
$ ./bin/trema dump_flows lsw1
cookie=0x0, duration=208.935s, table=0, n_packets=0, n_bytes=0, idle_age=208, priority=65535,udp,in_port=2,vlan_tci=0x0000,dl_src=bc:5a:3b:5d:3b:bb,dl_dst=b3:c2:12:54:9d:c7,nw_src=192.168.0.2,nw_dst=192.168.0.1,nw_tos=0,tp_src=0,tp_dst=0 actions=output:1
cookie=0x0, duration=15.382s, table=0, n_packets=0, n_bytes=0, idle_age=15, priority=65535,udp,in_port=1,vlan_tci=0x0000,dl_src=b3:c2:12:54:9d:c7,dl_dst=bc:5a:3b:5d:3b:bb,nw_src=192.168.0.1,nw_dst=192.168.0.2,nw_tos=0,tp_src=0,tp_dst=0 actions=output:2
```
上記の結果より，host1からhost2へ正しくパケットが送信され，FlowTableも
更新されていることがわかる．

#### 手順4〜6の動作について
手順4〜6の動作については，手順1〜3の送受信先が変化しただけで，
動作の本質は同じであるため説明は省略する．

#### 手順7 host1からhost3へパケットを送信する際の動作
パケットを受信したlsw1は，FlowTableにパケットが登録されていないため，
コントローラへPackatInを送信する．
コントローラはlsw1に対して，フラッディングモードを指定したPacketOutを
送信するが，宛先となるhost3はlsw2に接続されており，またlsw1とlsw2を繋ぐ
リンクも存在しないため，パケットはhost3へは到達しない．
以下の図に手順7の一連の動作を示す．

![fig5](https://github.com/handai-trema/learning-switch-nsyuyu/blob/master/fig5.jpg)

また，動作結果を以下に示す．
```
$ ./bin/trema send_packets --source host1 --dest host3
ensyuu2@ensyuu2-VirtualBox:~/learning-switch-nsyuyu$ ./bin/trema show_stats host1
Packets sent:
  192.168.0.1 -> 192.168.0.2 = 2 packets
  192.168.0.1 -> 192.168.0.3 = 1 packets
Packets received:
  192.168.0.2 -> 192.168.0.1 = 1 packet
ensyuu2@ensyuu2-VirtualBox:~/learning-switch-nsyuyu$ ./bin/trema show_stats host3
Packets sent:
  192.168.0.3 -> 192.168.0.4 = 2 packets
Packets received:
  192.168.0.4 -> 192.168.0.3 = 1 packet
```
上記の結果より，host1からhost3へはパケットを送信することができず，
コントローラは，FDBの管理をスイッチ毎に独立して行えていることがわかる．
