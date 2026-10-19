-- V40: move previously hard-coded organizer glossary and prompt examples to database.
-- The seeding is additive. Future changes use UPDATE with version=version+1, not edits to Flyway history.
CREATE TABLE homework_organizer_rule (
  code varchar(80) PRIMARY KEY,
  rule_type varchar(16) NOT NULL CHECK (rule_type IN ('SHORTHAND','PROMPT')),
  scope varchar(16) NOT NULL DEFAULT 'GLOBAL' CHECK (scope IN ('GLOBAL','STUDENT','TEACHER')),
  family_id uuid REFERENCES family(id) ON DELETE CASCADE,
  student_id varchar(80) REFERENCES student(id) ON DELETE CASCADE,
  teacher_name varchar(80) NOT NULL DEFAULT '',
  subject varchar(20) NOT NULL DEFAULT '',
  trigger_text varchar(120) NOT NULL DEFAULT '',
  meaning varchar(1200) NOT NULL DEFAULT '',
  short_title varchar(200) NOT NULL DEFAULT '',
  prompt_text text NOT NULL DEFAULT '',
  template_key varchar(32) NOT NULL DEFAULT '',
  priority integer NOT NULL DEFAULT 100,
  enabled boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 1 CHECK (version >= 1),
  origin varchar(24) NOT NULL DEFAULT 'MIGRATED',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_homework_organizer_rule_scope CHECK (
    (scope='GLOBAL' AND family_id IS NULL AND student_id IS NULL AND teacher_name='') OR
    (scope='STUDENT' AND family_id IS NOT NULL AND student_id IS NOT NULL AND teacher_name='') OR
    (scope='TEACHER' AND family_id IS NOT NULL AND student_id IS NOT NULL AND teacher_name <> '')
  ),
  CONSTRAINT chk_homework_organizer_rule_content CHECK (
    (rule_type='SHORTHAND' AND subject <> '' AND trigger_text <> '' AND meaning <> '') OR
    (rule_type='PROMPT' AND prompt_text <> '')
  )
);
CREATE INDEX idx_homework_organizer_rule_active ON homework_organizer_rule(enabled,rule_type,priority DESC);

INSERT INTO homework_organizer_rule(code,rule_type,subject,trigger_text,meaning,short_title,priority) VALUES ('GLOBAL_SHORTHAND_01','SHORTHAND',$seed$英语$seed$,$seed$一起作业$seed$,$seed$「一起作业」平台（APP）上布置的作业，是专有名称，不是「一起做作业」，与「听读U3」「听读课文U3」等其它作业不是同一项，即使写在同一行也要拆成多条$seed$,$seed$完成一起作业平台上的作业$seed$,1000);
INSERT INTO homework_organizer_rule(code,rule_type,subject,trigger_text,meaning,short_title,priority) VALUES ('GLOBAL_SHORTHAND_02','SHORTHAND',$seed$英语$seed$,$seed$听读绘本$seed$,$seed$阅读绘本$seed$,$seed$阅读绘本$seed$,999);
INSERT INTO homework_organizer_rule(code,rule_type,subject,trigger_text,meaning,short_title,priority) VALUES ('GLOBAL_SHORTHAND_03','SHORTHAND',$seed$英语$seed$,$seed$绘本$seed$,$seed$阅读绘本$seed$,$seed$阅读绘本$seed$,998);
INSERT INTO homework_organizer_rule(code,rule_type,subject,trigger_text,meaning,short_title,priority) VALUES ('GLOBAL_SHORTHAND_04','SHORTHAND',$seed$英语$seed$,$seed$绘$seed$,$seed$阅读绘本$seed$,$seed$阅读绘本$seed$,997);
INSERT INTO homework_organizer_rule(code,rule_type,subject,trigger_text,meaning,short_title,priority) VALUES ('GLOBAL_SHORTHAND_05','SHORTHAND',$seed$英语$seed$,$seed$听读U*$seed$,$seed$听读课文：U 是 Unit（单元）的缩写，U 后面的数字就是单元号，「听读U3」「听读课文U3」都指听读课本第3单元课文$seed$,$seed$听读课本第*单元课文$seed$,996);
INSERT INTO homework_organizer_rule(code,rule_type,subject,trigger_text,meaning,short_title,priority) VALUES ('GLOBAL_SHORTHAND_06','SHORTHAND',$seed$英语$seed$,$seed$听读课文U*$seed$,$seed$听读课文：U 是 Unit（单元）的缩写，U 后面的数字就是单元号，「听读U3」「听读课文U3」都指听读课本第3单元课文$seed$,$seed$听读课本第*单元课文$seed$,995);
INSERT INTO homework_organizer_rule(code,rule_type,subject,trigger_text,meaning,short_title,priority) VALUES ('GLOBAL_SHORTHAND_07','SHORTHAND',$seed$语文$seed$,$seed$课外30分$seed$,$seed$课外阅读 30 分钟$seed$,$seed$课外阅读30分钟$seed$,994);
INSERT INTO homework_organizer_rule(code,rule_type,subject,trigger_text,meaning,short_title,priority) VALUES ('GLOBAL_SHORTHAND_08','SHORTHAND',$seed$语文$seed$,$seed$国*$seed$,$seed$国学课本对应页，「国」后面的数字是页码（国13＝国学第13页，国20＝第20页）$seed$,$seed$国学第*页$seed$,993);
INSERT INTO homework_organizer_rule(code,rule_type,subject,trigger_text,meaning,short_title,priority) VALUES ('GLOBAL_SHORTHAND_09','SHORTHAND',$seed$语文$seed$,$seed$久$seed$,$seed$久久积累$seed$,$seed$完成久久积累$seed$,992);
INSERT INTO homework_organizer_rule(code,rule_type,subject,trigger_text,meaning,short_title,priority) VALUES ('GLOBAL_SHORTHAND_10','SHORTHAND',$seed$语文$seed$,$seed$订小白$seed$,$seed$订正《小白练》练习单$seed$,$seed$订正《小白练》练习单$seed$,991);

INSERT INTO homework_organizer_rule(code,rule_type,subject,prompt_text,priority,template_key) VALUES ('PROMPT_THREE_PART','PROMPT',$seed$语文$seed$,$seed$当老师通知出现「学习进度 / 常规作业 / 今日作业」三段式模板时按下面处理，其他格式不得套用：「学习进度」段（常带🔔，写「今天我们学了《…》」）只是告知当天学了哪篇课文，孩子没有对应的动作可做，**不要为它生成任务**；但要把这里的课文篇名用到后面各项作业的 title 里，例如学习进度是《黄山奇石》时，「正确、流利、有感情地朗读课文三遍」的标题要写成「正确流利有感情朗读《黄山奇石》3遍」。「常规作业」段（常带🌷）一般是固定的两项——课外阅读 30 分钟、完成家校联系本心情日记——这是两个不同的动作，必须拆成两条任务，即使写在同一个句子里用逗号连接也一样；心情日记后面括号里给的主题要保留进 title，例如「完成家校联系本心情日记：我们班被评为卓越班级啦」。⚠️最常见的漏项是把日记并进课外阅读那一条：title 只写「阅读课外书30分钟」，心情日记却留在它的 instruction 里——这样孩子只看到一条任务，等于漏了。这两项必须各自独立成条，日记那一条要有自己的 title。这两项连同「今日作业」里的内容都属于布置这份作业的语文老师，subject 一律填「语文」，不要因为出现「阅读」「日记」字样就归到「阅读」或「实践」。「今日作业」段（常带🌈）是分点布置的，按前面的拆项规则逐条拆；同一个序号下面带🌟的多个子项如果动作不同（例如「记一记」里的本课字词与多音字），也要逐条拆开，每一条的 title 都要带上各自的动作和具体内容。⚠️注意：「记一记」「创意表达」这类短语只是分组小标题，不是任务本身，必须用小标题下面的具体要求来写 title：例如「记一记：本课字词…每一个字听写过关」要写成「过关复习《黄山奇石》田字格生字、课课贴、词语表词语，逐字听写过关」，「创意表达…模仿课文2-4段…用上『好像』或『真像』…写在2号本上」要写成「模仿《黄山奇石》2-4段创编，用上『好像/真像』和2-3个动作词，写在2号本」，禁止直接把「记一记」「创意表达」「背诵摘抄」这类分组名当标题。同一个序号里用逗号、顿号或句号连起来的多个不同动作同样要各自成条，例如「背诵摘抄28，大声朗读《国学》16-19页内容，按要求预习《葡萄沟》」要拆成背诵摘抄28、朗读《国学》16-19页、预习《葡萄沟》三条，不能并成一条。「常规作业」里的「课外书」「课外阅读」按原文照写，不要套用简写词典改成「绘本」。三段式通知整理完必须自检：逐条对照原文的每一个序号和每一个🌟子项，原文有 N 个不同的动作就要有 N 条任务，少一条就是漏作业。这类通知里一项作业的描述往往很长（带要求、例子、表达支架），title 必须先归纳再落笔：保留「做什么 + 写在哪/哪一课 + 硬性要求（必用词、遍数、页数、题号）」，删掉解释性、举例性和「可参考表达支架」这类示范文字；删掉的原文信息原样挪进 instruction，不允许丢失。输出前最后核对一次：学习进度有没有被误当成作业？常规作业的课外阅读与心情日记两条都在不在？今日作业的每个序号、每个🌟子项是不是都有对应条目？少的要补齐再输出。拆解范例：原文「🔔学习进度：今天我们学了《黄山奇石》。🌷常规作业：阅读课外书30分钟，完成家校联系本心情日记（主题：我们班被评为『卓越班级』啦！）。🌈今日作业：1⃣记一记：🌟本课字词：过关复习本课的田字格生字、课课贴和词语表词语，要求熟记，每一个字听写过关。🌟多音字：都 dōu（都有）dū（首都）2️⃣正确、流利、有感情地朗读课文三遍。3️⃣创意表达，写在2号本上。🌟根据第44页的图片，模仿课文2-4段选择一幅图创编，要用上『好像』或『真像』，用上2-3个表示动作的词语。📝可参考表达支架：那巨石好像……在哪里做什么，这就是有名的『……』。🌟读一读第44页课后最后一题的词语，并选择几个词语介绍一处景物。4️⃣背诵摘抄28，大声朗读《国学》16-19页内容，按要求预习《葡萄沟》」应整理成 10 条：①课外阅读30分钟；②完成家校联系本心情日记（主题：我们班被评为『卓越班级』啦）；③过关复习《黄山奇石》田字格生字、课课贴、词语表词语并逐字听写过关；④掌握多音字「都」dōu（都有）dū（首都）；⑤正确流利有感情朗读《黄山奇石》3遍；⑥模仿《黄山奇石》2-4段创编，用上『好像/真像』和2-3个动作词，写在2号本；⑦读第44页课后最后一题词语并选几个介绍一处景物；⑧背诵摘抄28；⑨大声朗读《国学》16-19页；⑩按要求预习《葡萄沟》。注意「表达支架」只是示范，不单独成条；它服务的那条创编作业要写清支架里的硬性要求。$seed$,300,'THREE_PART');

INSERT INTO homework_organizer_rule(code,rule_type,subject,prompt_text,priority) VALUES ('PROMPT_ENGLISH','PROMPT',$seed$英语$seed$,$seed$当英语作业出现下列简写或分点写法时，按规则解析；不要根据姓名猜测两位老师是否同一人：①「U＋数字」＝Unit（单元），U 后面的数字就是单元号；「听读U4」「听读课文U4」都是「听读课本第 4 单元课文」，单元号必须写进 title。②老师常在一个序号里用「/」「、」「和」并列多个听读对象，并列的每个对象都是一项独立的作业，必须逐条拆开，例如「听读课文U4/绘本，10分钟」是「听读课文第4单元」与「听读绘本」两项，句尾的时长是每一项各自的时长，不是两项合计。③⚠️「绘本」「绘」「听读绘本」指的是阅读绘本，这一项由系统的定时语音任务自动布置，标题格式是「绘本-文件夹目录」，**整理结果里不要输出这一条任务**，否则孩子会看到重复作业；同一条里除了绘本还有别的作业时，只去掉绘本那一条，其余各项照常保留。④「一起作业」是 APP 名称，指在该 APP 上布置的作业，不是「一起做作业」；它即使和「绘本」挤在同一行、即使只有四个字，也永远要单独保留一条，不能跟着绘本一起被删掉。⑤⚠️老师写的序号点数不等于作业任务数：可能只写了两点却是三个任务，必须按原文里出现的可执行动作数量来定条数，不要照抄序号个数。⑥英语作业的文字通常很简短，title 不能因为原文短就照抄，要把简写展开成完整说法（如「听读课文U4」→「听读课本第4单元课文」）。拆解范例：原文「英语：1、听读课文U4/绘本，10分钟  2、一起作业。」应整理成 2 条：①听读课本第4单元课文（约10分钟）；②完成一起作业 APP 上布置的作业。其中「听读绘本」不生成任务，因为定时语音任务已经生成过「绘本-…」了，再生成一次就是重复作业。$seed$,200,'ENGLISH');

INSERT INTO homework_organizer_rule(code,rule_type,subject,prompt_text,priority) VALUES ('PROMPT_BLACKBOARD','PROMPT',$seed$$seed$,$seed$当图片中有黑板/白板《作业公示栏》时，按照表格版式解析（表头「学科」「内容」「预计时长」，右侧可能还有「上午」「下午」）。⚠️下面这几条只适用于这种黑板表格；微信群里的三段式文字通知仍按前面「三段式模板」那一条逐动作拆，不要拿这里的「一个序号一条」去合并那边的动作。①标题「作业公示栏」、表头「学科/内容/预计时长」「上午/下午」和顶部的「26年10月16日 星期五」都是版式信息，不是作业；顶部那个日期就是这份作业的日期，用它填 taskDate。②学科是行标题，只作用到本行；「内容」格里的字才是作业。行内用序号「1. 2.」分的，一个序号就是一条任务：序号里写了两个动作（如「1.复习P28-38。周一练习」）时并成这一条，但两个动作都必须写进 title，完整内容进 instruction，不能只留前半个、也不能丢后半个。同一格里没有序号、只用逗号/换行并列的独立项目（如「一起作业，绘本」「听读U3」）要各自成条。③「其他」行不是新科目：这一行写的是课外阅读、日记、摘抄、练字这类语文常规作业，subject 一律填「语文」，填成「阅读」「实践」「其他」都算错。④格子里跨行的内容（「日记一件事，120字以上」下一行接着写「写详细」）是同一件事的续写，并进上一条，既不拆成两条也不能丢。⑤「预计时长」列的分钟数只作用在同一行的作业上，直接用作 expectedMinutes；内容格里手写的「(25分)」同理。一行拆成多条时，每条都用这一行的时长。⑥同一格里「一起作业」这四个字永远是一项必须保留的作业，不能因为和「绘本」写在同一行、或者只有四个字就省掉。⑦黑板上字少，title 不能照抄成「数学写口算单」这种半截话：去掉「语文/数学/英语」这类前缀（subject 已经单独给出），写成完整动作，如「复习课本第28-38页」「完成口算单」「订正《小白练》练习单」；简写必须展开，不能把「订小白」「U3」原样留在标题里。整理范例：黑板原文「语文｜1.复习P28-38。周一练习 2.预习8、10课 订小白｜15分钟；数学｜写口算单｜5分钟；英语｜一起作业，绘本 听读U3｜10分钟；其他｜课外30分；日记一件事，120字以上(25分) 写详细」应整理成 7 条：①复习课本第28-38页并完成周一练习（15分钟）；②预习第8、10课并订正《小白练》练习单（15分钟）；③完成口算单（5分钟）；④完成一起作业 APP 上布置的作业（10分钟）；⑤听读课本第3单元课文（10分钟）；⑥课外阅读30分钟（30分钟）；⑦日记一件事：120字以上，写详细（25分钟）。其中「绘本」不生成任务；「其他」行的两项都归语文；「写详细」并进日记那一条，不单独成条；语文两个序号各自只有一条任务，不要拆成四条，否则同一行的 15 分钟会被重复计算。$seed$,100,'BLACKBOARD');
