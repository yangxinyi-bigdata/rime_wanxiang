大坑: 分词器处理完了之后,要返回true和false, 我处理完了不代表后面的不处理了,比如ai对话模式后面可能还要存在英文模式等等,所以仍然要继续交给后面继续分词啊!

首先这代码的功能非常的简单,当检查到最后一个`local segment = segmentation:back()`
中存在反引号的时候,就将整个最后一个seg添加上两个标签: `new_segment.tags = Set{"rawenglish_combo", "abc"}`.

这样看只要是有反引号,一定是标记成功了的.

