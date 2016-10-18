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
登録されているかを確認する．
宛先MACアドレスとそれに対応するポート番号がFDBに登録されている場合，flow_modメソッドを
呼び出し，FlowModの処理を行う．
最後に，宛先MACアドレスがFDBに登録されているかどうかに関わらず，packet_outメソッドを
呼び出し，PacketOutの処理を行う．
このとき，宛先MACアドレスとそれに対応するポート番号がFDBに登録されていない場合は，
PacketOutメッセージをフラッディングで出力するように，オプションを指定する．
flow_modメソッド，packet_outメソッドについては，特筆すべき変更点がないので，
説明は省略する．

###ラーニングスイッチの動作の解説
2つのスイッチが存在する環境における，ラーニングスイッチの動作の解説を行う．
動作環境の設定ファイル(trema.multi.conf)と概念図を以下に示す．
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