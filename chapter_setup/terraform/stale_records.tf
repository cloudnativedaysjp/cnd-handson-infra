# 以前のイベントで作られた *.vm01〜*.vm45 を消す。apply が済んだらこのファイルごと消す
removed {
  from = aws_route53_record.stale
  lifecycle {
    destroy = true
  }
}
