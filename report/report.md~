# 第二回レポート課題(10/12出題，10/18解答)
## 課題内容(Cbenchのボトルネック調査)
Rubyのプロファイラを用いて，CbenchやTremaのボトルネック部分を
発見し，遅い理由を解説せよ．
## 解答
ruby-profを用いて，Cbenchプログラムのプロファイリングを行った．
プロファイリングの結果を以下に示す．なお，全体時間のパーセンテージが上位
10件以内のメソッドについての結果を記載している．
```
 %self      total      self      wait     child     calls  name
  2.72      6.798     2.995     0.000     3.803   123066   Kernel#clone
  2.67      8.198     2.944     0.000     5.254   231506  *BinData::BasePrimitive#_value
  2.61     26.885     2.881     0.000    24.004   119178   BinData::Base#new
  2.37      2.681     2.612     0.000     0.069   381930   Kernel#respond_to?
  2.17      6.898     2.388     0.000     4.510   198543  *BinData::BasePrimitive#snapshot
  2.00      3.652     2.210     0.000     1.442   123066   Kernel#initialize_clone
  1.91     23.689     2.106     0.000    21.583   105553   BinData::Struct#instantiate_obj_at
  1.91      2.103     2.103     0.000     0.000   127489   BasicObject#!
  1.52      1.680     1.680     0.000     0.000    98290   BinData::BasePrimitive#initialize_instance
  1.52      6.028     1.671     0.000     4.357    81839   Kernel#dup
```
上記の結果から，Kernelモジュールのメソッドやバイナリデータを扱うBinDataクラスのメソッドの実行時間が
長いことがわかる．
現状のCbenchコントローラのプログラムでは，CbenchプロセスがPacketInする度に，
FlowModメッセージを一から作り直している．
FlowModメッセージの作成には，バイナリデータを容易に扱うために，BinDataクラスのメソッドを
利用していると考えられ，その中でも特にインスタンスを生成するnewメソッドの処理が遅く，
Cbenchのボトルネックとなっている．

## 発展課題内容(Cbenchの高速化)
Cbenchのボトルネックを改善し，高速化せよ．
## 解答
Cbenchプロセスが送信するPacket Inの内容はすべて同じものであるため，
PacketInする度に，FlowModメッセージを作り直す必要はなく，
一度目のPacketInで，生成したFlowModメッセージをキャッシュし，二度目以降の
PacketInに対しては，キャッシュしたFlowModメッセージを送信すればよい．
このように，プログラムを書き換えることで，Cbenchプログラムのボトルネックとなっていた
BinDataクラスのnewメソッドの呼び出し回数が減り，ボトルネックが改善され，
プログラムの高速化が期待できる．
キャッシュを利用し，高速化を図ったプログラム(lib/fast_cbench.rb)を以下に記す．
なお，以下のプログラムは，文献[1]を参考に作成した．
```ruby
class FastCbench < Trema::Controller
  def start(_args)
    logger.info "#{self.class.name} started."
  end

  def packet_in(dpid, packet_in)
    @flow_mod ||= create_flow_mod_binary(packet_in)
    send_message dpid,@flow_mod
  end

  private

  def create_flow_mod_binary(packet_in)
    options = {
      command: :add,
      priority: 0,
      transaction_id: 0,
      idle_timeout: 0,
      hard_timeout: 0,
      buffer_id: packet_in.buffer_id,
      match: ExactMatch.new(packet_in),
      actions: SendOutPort.new(packet_in.in_port + 1)
    }
    FlowMod.new(options).to_binary.tap do |flow_mod| 
      def flow_mod.to_binary
        self
      end
    end
  end
end
```
高速化前のCbenchプログラムのベンチマークの結果を以下に示す．
```
1   switches: fmods/sec:  49   total = 0.004876 per ms 
1   switches: fmods/sec:  15   total = 0.001438 per ms 
1   switches: fmods/sec:  30   total = 0.002857 per ms 
1   switches: fmods/sec:  14   total = 0.001337 per ms 
1   switches: fmods/sec:  20   total = 0.001939 per ms 
1   switches: fmods/sec:  11   total = 0.001008 per ms 
1   switches: fmods/sec:  18   total = 0.001748 per ms 
1   switches: fmods/sec:  23   total = 0.002286 per ms 
1   switches: fmods/sec:  15   total = 0.001459 per ms 
1   switches: fmods/sec:  14   total = 0.001330 per ms 
RESULT: 1 switches 9 tests min/max/avg/stdev = 1.01/2.86/1.71/0.54 responses/s
```
高速化後のCbenchプログラムのベンチマークの結果を以下に示す．
```
1   switches: fmods/sec:  282   total = 0.028167 per ms 
1   switches: fmods/sec:  170   total = 0.016958 per ms 
1   switches: fmods/sec:  200   total = 0.019817 per ms 
1   switches: fmods/sec:  130   total = 0.012910 per ms 
1   switches: fmods/sec:  137   total = 0.013619 per ms 
1   switches: fmods/sec:  176   total = 0.017585 per ms 
1   switches: fmods/sec:  291   total = 0.029099 per ms 
1   switches: fmods/sec:  216   total = 0.021453 per ms 
1   switches: fmods/sec:  181   total = 0.018049 per ms 
1   switches: fmods/sec:  153   total = 0.015242 per ms 
RESULT: 1 switches 9 tests min/max/avg/stdev = 12.91/29.10/18.30/4.61 responses/s
```
以上の結果より，高速前のプログラムでは，1秒間に打てるFlowModの数が，平均20.9回であったのに
対して，高速化後のプログラムでは，平均193.6回となっており，高速化が実現されたことを
確認した．


##参考文献
[1]:高宮 安仁，鈴木 一哉，松井 暢之，村木 暢哉，山崎 泰宏，[TremaでOpenFlowプログラミング](http://yasuhito.github.io/trema-book/)