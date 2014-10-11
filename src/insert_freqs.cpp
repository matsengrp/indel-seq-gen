#include "insert_freqs.h"
#include <stdio.h>

/* From Xia, X. & Xie, Z. (2002).  Mol. Biol. Evol. 19(1):58-67. */
/* AAs:  ARNDCQEGHILKMFPSTWYV */
static double xiaNeighborRates[SQNUM_AA] = {
	0.101347022392369,  0.0556843079405507, 0.0342964714815664, 0.0521961289914338, 0.0122600393903201, 0.046002831673614, 0.0609047118099773, 0.0764789166871001, 0.0197900764868264, 0.0628979569237584, 0.117807113986728, 0.0433609909275708, 0.0282060003005687, 0.037523630237212, 0.0370015898502693, 0.0557554952660429, 0.0507091048589305, 0.0169584028728041, 0.0205731370672404, 0.070246070855118,
	0.0793252606885704, 0.0633246098146365, 0.0383744423501973, 0.0539276173946059, 0.0114580932105713, 0.0531953842190191, 0.0690333166094892, 0.0601380395134717, 0.0285435339742634, 0.0609787516780344, 0.110879086606913, 0.0453713371391379, 0.0234857011132656, 0.0447882625733928, 0.0376557690482325, 0.0498596553080125, 0.0455069358753576, 0.0171939197526679, 0.0390524360312962, 0.067907847098865,
	0.0930082412365653, 0.0518020584102389, 0.0463711974478751, 0.0542516425506058, 0.0105958755839125, 0.0430671072120314, 0.0532262352360336, 0.08423531198967, 0.0223121036041168, 0.0657589913030269, 0.0926474497740306, 0.044795108427329, 0.0228248072614029, 0.0366108389350955, 0.0545174888914208, 0.0544225437697011, 0.05258060840834, 0.0160077475219323, 0.0322623523603357, 0.0687022900763359,
	0.0978950445841251, 0.0488378891974857, 0.0453734834088584, 0.0569945914340009, 0.0108756029820202, 0.0316035667300102, 0.06921502704283, 0.0726063441017395, 0.0192954246455197, 0.0685864639672562, 0.0902499634556351, 0.0513959947376115, 0.0224674755152755, 0.0405350095015349, 0.0427569068849583, 0.0543633971641573, 0.0491887151001316, 0.0158602543487794, 0.0376260780587633, 0.0742727671393071,
	0.0893886966551326, 0.0583749839805203, 0.0321030372933487, 0.055363321799308,  0.0188389081122645, 0.042483660130719, 0.0574778931180315, 0.095604254773805, 0.0301806997308727, 0.0545303088555684, 0.0940663847238242, 0.0307574009996155, 0.0184544405997693, 0.0415865692682302, 0.0492118415993849, 0.0651031654491862, 0.0463924131744201, 0.0180058951685249, 0.0330642060745867, 0.0690119184928873,
	0.0989556843996881, 0.0661851964873021, 0.0358051062964093, 0.0393822262909843, 0.00881565117146441, 0.0734411555284305, 0.0519445292103211, 0.0675414505136812, 0.0286508663072594, 0.0531482046587326, 0.113094632624691, 0.0431966907401756, 0.0239717899162513, 0.0344318990947004, 0.0488420981249788, 0.0523344522429051, 0.0503678839046553, 0.0165971586478147, 0.0284304750279727, 0.0648628488115824,
	0.0896708880652723, 0.0627316421546158, 0.0447503175871236, 0.0422881988553767, 0.00936390900637793, 0.0603350053040324, 0.0640936652828163, 0.0634388464711814, 0.0252105242479406, 0.0618803776994905, 0.1055436960593, 0.0602695234228689, 0.0288120277119321, 0.032570687690716, 0.0360150346399151, 0.0524771795644145, 0.0517830716240816, 0.0145107848658276, 0.0278559922469453, 0.0663986274997708,
	0.0833222997402862, 0.0496307990018842, 0.0397311198248205, 0.0499872689310995, 0.0146152670978255, 0.0376126699597698, 0.062219279930743, 0.0737179813617151, 0.022243723583032, 0.069766257574986, 0.0998523196007537, 0.0560167031623975, 0.0298518103579977, 0.0446911442684728, 0.0272139328818048, 0.0548250751133065, 0.0514233335030809, 0.0173448082701024, 0.036237714518511, 0.079696491317411,
	0.0832947403241813, 0.055342375124049,  0.0400264637777043, 0.0515712868011909, 0.0158782666225604, 0.0513397287462785, 0.0510750909692359, 0.0764141581210718, 0.0332782004631161, 0.0615944426066821, 0.0982467747270923, 0.0357260999007608, 0.0194508766126365, 0.0459146543169037, 0.059014224280516, 0.0565663248428713, 0.0475024809791598, 0.0177968905061197, 0.0408534568309626, 0.059113463446907,
	0.109566823036231,  0.0509282363509332, 0.048220880327378,  0.0595618325182154, 0.0130751572013175, 0.0312406427787204, 0.0552200818444955, 0.0784634195029444, 0.0208229364208005, 0.0611088931031041, 0.0854002395448648, 0.0423694979538876, 0.0224448547759257, 0.037478790298433, 0.048545263998403, 0.0672971354426589, 0.0612461323485378, 0.0120021958279269, 0.0268614632198822, 0.0681455235053399,
	0.10467338490723,   0.056916990472698,  0.0416422783721078, 0.0489270325733588, 0.0124891574931419, 0.0387720993208888, 0.0519100442162719, 0.0660634824369019, 0.0212195792754737, 0.0562540989964951, 0.109574550608943, 0.043482860024118, 0.0263040979386896, 0.0402177669019696, 0.0533627638343335, 0.0643639415245094, 0.0599141061895729, 0.0136597956319683, 0.0240403940678265, 0.0662115752135004,
	0.0985780530791739, 0.0601632415598638, 0.0443010899881932, 0.0491778032545644, 0.00764873975462432, 0.0467822248079259, 0.0624048185349327, 0.0688557690662377, 0.0208928663096114, 0.0586403381187865, 0.102120086925275, 0.0534898444585137, 0.0241097859379545, 0.0284560496911415, 0.0509573758149245, 0.0539347375986037, 0.0607963587207611, 0.0108827706575863, 0.0269331462500642, 0.0708748994712616,
	0.103173196241801,  0.0533888790403593, 0.0373751698871359, 0.0445547479761272, 0.00901140459729362, 0.0452933876972168, 0.0466229391951782, 0.0745435206523666, 0.0190864503929563, 0.0567866217573716, 0.120811912781422, 0.0418660993913609, 0.0340365183478107, 0.0335046977486261, 0.051054777521716, 0.0594161791644507, 0.0633457424806476, 0.0104591384506293, 0.0208296401347279, 0.0748389765408025,
	0.0975112120570516, 0.0484283871961196, 0.04671530036764,   0.0592458568321367, 0.0149750736242373, 0.0270051777568187, 0.045387176871403, 0.082054934267511, 0.0212499759397917, 0.0679267799742075, 0.0862702827555675, 0.0353781302330953, 0.0237522375993687, 0.0445210093738571, 0.0399591938867823, 0.0808422997709468, 0.0639616576521086, 0.0165149269532077, 0.0317402267434027, 0.0665601601447462,
	0.0953526183862882, 0.0448987195989432, 0.0291308176952781, 0.0610900345505047, 0.00946751575096538, 0.0529266309870605, 0.0773829686335614, 0.0796863356141183, 0.0237788767698665, 0.0440180204593185, 0.115574825553824, 0.035769934286295, 0.0233215906781383, 0.0422396856581532, 0.0371926021272272, 0.0486586274642639, 0.0476424361493124, 0.0169534584377752, 0.0273016733283653, 0.0876126278707405,
	0.0916003969737198, 0.0586954000025778, 0.0345160916132857, 0.0514519184914999, 0.0114581050949257, 0.0432160026808615, 0.0553443231469189, 0.0901181899029477, 0.0245401935891322, 0.0530372356193692, 0.114052611906634, 0.036526737726681, 0.0233544279325145, 0.0394395968396768, 0.0441955482232848, 0.060100274530527, 0.0518901362341629, 0.0168327168211169, 0.0280846018018482, 0.0715454908683156,
	0.0940014681237102, 0.0558302516585643, 0.0313153557429953, 0.0491267433969059, 0.010470769102921, 0.0404980540435728, 0.0487250869101536, 0.0843617124416559, 0.0232545255605878, 0.0575338291713411, 0.133100649575491, 0.0293486239802773, 0.0224650628107644, 0.039777842412155, 0.0591543053420313, 0.0538773701195274, 0.0560657054611432, 0.0158031052201493, 0.0221603578897799, 0.0731291810362737,
	0.0672401081346768, 0.0721061685917916, 0.0328336200540673, 0.0412386335709019, 0.0138608994839027, 0.084050135168346, 0.0380928975178176, 0.0616859179159499, 0.029687884000983, 0.0508232981076432, 0.152076677316294, 0.0360776603588105, 0.0282624723519292, 0.0460555419021873, 0.042909805849103, 0.0556402064389285, 0.0389284836569182, 0.0162693536495453, 0.0302777095109363, 0.0618825264192676,
	0.086363157340078,  0.0644166930129624, 0.038123089893561,  0.0558278006112341, 0.0142533459795553, 0.0559068394983665, 0.0463958267467594, 0.0788281167667826, 0.0264253345979555, 0.0529560543787543, 0.105727684687533, 0.0363842343766466, 0.0198387606702498, 0.0429708083043524, 0.0490041100221309, 0.0637843819159026, 0.0538781747286332, 0.0155443144693856, 0.0345136473811782, 0.0588576246179787,
	0.0984534057978707, 0.0501555086140096, 0.0411752842145488, 0.0536265882577728, 0.0119948623775303, 0.0329168745422315, 0.0581167004575032, 0.0686679333807467, 0.0180559831010434, 0.0673516829959557, 0.100937297653041, 0.0462067574596368, 0.0300190007111998, 0.0365896377126965, 0.0425127644442557, 0.0629783349432632, 0.0609721145987029, 0.0140010827220907, 0.0249450677762799, 0.0803231182396213,
};

static double spNeighborRates[SQNUM_AA] = {
	0.100725386734048,  0.0524636724852246, 0.036316348338772,  0.0509280528662272, 0.0136525170086411, 0.0405655058827415, 0.0666863346087468, 0.0705900833034936, 0.0205918474128023, 0.0585276105627359, 0.102128979661696, 0.0562307965441474, 0.02297461484239, 0.0366641969136345, 0.046024673508408, 0.0636084330430435, 0.0539314489643177, 0.0102924517891446, 0.0264768409982006, 0.0706202045315839,
	0.0767053713460983, 0.0700100357321454, 0.0388346477650088, 0.0511912887375488, 0.0157712593917784, 0.0424642489904246, 0.0694678455279255, 0.0677485318540175, 0.0241111380163549, 0.0573533517493248, 0.0992386425763364, 0.0602847733317053, 0.0212264995462313, 0.0386971794996676, 0.0445110444501304, 0.064234859455162, 0.0482299588898546, 0.0122003771459695, 0.0324869614368589, 0.0652319845574571,
	0.0680612187115638, 0.0497794197559566, 0.0503242316797758, 0.0497055588753872, 0.0155151814005641, 0.0391518941974541, 0.0662041451429612, 0.0673074860112768, 0.0219190956051721, 0.0664570307292918, 0.0950017990400196, 0.0644015879385886, 0.0218348590294751, 0.0419946588031794, 0.0505380765149482, 0.0676597320678971, 0.0516210177114874, 0.0130199146519939, 0.0337129196397137, 0.0657901724932936,
	0.0750194619866486, 0.0515757850865893, 0.0390682795050905, 0.0560695965065734, 0.0149898764495586, 0.0337937770297691, 0.0706736888315841, 0.0685874689133466, 0.0199652614596269, 0.0655253851759375, 0.098785892713587, 0.0582728924382441, 0.0218224436514668, 0.0444265459286298, 0.0493270133480478, 0.064183503312408, 0.0505290121825402, 0.0122679628054896, 0.033816445821036, 0.0712997068538261,
	0.0692036354573146, 0.0546783586789218, 0.0419638661265865, 0.0515819033829844, 0.026263268144467, 0.0391309187006874, 0.056022534203702, 0.0759654186350483, 0.0282333937720819, 0.0575878851067635, 0.0936708644009429, 0.0520480364382868, 0.018591574216944, 0.0434892627677649, 0.0488821368300289, 0.074817209251885, 0.0549580385121033, 0.0128628940964724, 0.0335996316597571, 0.0664491696172572,
	0.0804273194360131, 0.0575841627924673, 0.0414192211515009, 0.0454848282512159, 0.0153056070327394, 0.0600916561567632, 0.0681929173637869, 0.0639520573519806, 0.0242697376731809, 0.0560407464881047, 0.100657868176694, 0.0589798606125406, 0.0219518225651705, 0.0367502752047454, 0.0489510034159434, 0.0639983821663232, 0.0499699632880497, 0.0126686274404015, 0.0308303732273084, 0.0624735702050701,
	0.0787511200342011, 0.0561095303136716, 0.0417164675113067, 0.0566579398374031, 0.0130516812536139, 0.0406174322200624, 0.0879755699015478, 0.0622739015797164, 0.0198330547884274, 0.0610147426752589, 0.0954105137275248, 0.071077708377335, 0.0222627228460825, 0.0357176496557398, 0.0453956538129699, 0.057134543062614, 0.0494402987142018, 0.0103453151598388, 0.0280814708944029, 0.0671326836340813,
	0.0794289449585795, 0.0521396245033936, 0.0404111231396033, 0.0523917617839072, 0.01686300044842, 0.0362946758383538, 0.059336412265993, 0.0810606574933605, 0.0235271112511405, 0.0588777504793301, 0.0914812759033309, 0.0565551944661569, 0.0221265245568302, 0.0423134503519205, 0.0472773238731876, 0.0718579635099917, 0.0573202642880168, 0.0119026112363057, 0.0326315054823493, 0.066202824169829,
	0.0703603335547798, 0.0563486088631589, 0.0399629611579512, 0.0463116982719482, 0.0190317831227027, 0.0418264458358235, 0.0573855168893529, 0.0714440531368872, 0.0338062796740377, 0.0591124144246283, 0.100796822457235, 0.0509277665629545, 0.0212056348288236, 0.0441878643926938, 0.0558561256447811, 0.0686789650670367, 0.0534049315012274, 0.0124409725517556, 0.0343394825335184, 0.0625713395287038,
	0.077362151864115,  0.0518512776274573, 0.0468717460856903, 0.0587977160661118, 0.0150169831458479, 0.0373615565082627, 0.0682940140069867, 0.0691645979084405, 0.022867246187707, 0.0628554382966373, 0.0904437323602573, 0.0616411604229755, 0.0200767636952001, 0.0404040729782242, 0.0450041891966479, 0.0676005484715789, 0.0559473258909717, 0.0109015858171352, 0.0302319221125706, 0.0673059713571819,
    0.0827519225275915, 0.0549974844793861, 0.0410736578041927, 0.0543384386071931, 0.0149732971613355, 0.0411367644117054, 0.0654644376399132, 0.0658758471016618, 0.0239025019640981, 0.0554421199501503, 0.100742475848607, 0.0577978972118056, 0.020797124650072, 0.0403348543039505, 0.0478560214386071, 0.0703675929474793, 0.0559537396633468, 0.0115393092958998, 0.0290034926846136, 0.0656510203083906,
    0.0745189115141398, 0.0546427830633773, 0.0455398184132524, 0.0524254261239989, 0.013607565501005, 0.0394229673958622, 0.0797637919825467, 0.0666085021356563, 0.0197521474699673, 0.0618009748362133, 0.0945312076419041, 0.0789794910338248, 0.0216893347506378, 0.0346370776998879, 0.0432166361833456, 0.0617845601025473, 0.0506849669392341, 0.0110407737010101, 0.0300050139550107, 0.0653480495565784,
    0.0841769166451215, 0.0531931937575981, 0.0426871950448047, 0.0542789305183482, 0.0134383130992524, 0.0405666046900528, 0.0690721798348635, 0.0720481574792754, 0.0227385870432204, 0.0556507131894669, 0.09404137489067, 0.0599651244024666, 0.0282931035431187, 0.0379117410844441, 0.0448648570595581, 0.0645463284357139, 0.0534572361363999, 0.0115260686840238, 0.0281937438458873, 0.0693496306157138,
    0.0715224887969249, 0.0516312530328982, 0.0437116248572902, 0.0588336940319886, 0.0167365640437349, 0.0361588274886606, 0.059001550244563, 0.0733573750290362, 0.0252273060505666, 0.0596290432616897, 0.0971072901399211, 0.0509858211838933, 0.0201850298983582, 0.046131719717101, 0.0458877149936967, 0.0753707343334049, 0.0557551708225266, 0.0125321045599595, 0.0347780865819551, 0.0654566009318308,
    0.0743993792998314, 0.0492129379277078, 0.0435912935121512, 0.054131061477682,  0.0155887967563411, 0.0399110815154367, 0.0621402475974793, 0.0679197974078335, 0.0264251113566743, 0.0550381453017836, 0.0954742129568885, 0.0527153736297991, 0.0197942982652401, 0.0380254696396162, 0.0625460083381936, 0.0736720436917098, 0.0598279422773113, 0.0104712057768195, 0.0297415797061989, 0.0693740135653021,
    0.0727050202502708, 0.0502173038915635, 0.0412650549751335, 0.0498030852744424, 0.0168707746242081, 0.0368953810548503, 0.0553004377396277, 0.0729943941055254, 0.0229742248121671, 0.0584564146450628, 0.0992643490230522, 0.0532889784062536, 0.0201361515787017, 0.0441623329410305, 0.0520923349284647, 0.0896608480498744, 0.0561183639887644, 0.0114475353295124, 0.0304734909201713, 0.0658735234613232,
    0.0776551585857169, 0.0474982955544981, 0.0396604133851193, 0.0493914933644849, 0.0156114507391605, 0.0362902996986719, 0.0602822448256602, 0.0733502007908411, 0.022504895805213, 0.0609452423744473, 0.0994324730173374, 0.0550700058936118, 0.0210082534885399, 0.0411540832245001, 0.0532909782341701, 0.0706941572175667, 0.061192498440125, 0.0117046697888487, 0.0301391632800692, 0.0731240222914179,
    0.0696538896533943, 0.0564719389812469, 0.0470150737047454, 0.0563614437785803, 0.0171731135960537, 0.0432423610665708, 0.0592857564698434, 0.0715869206701598, 0.0246404301946557, 0.0558146830343507, 0.0963778529512062, 0.0563811297054922, 0.0212893774103354, 0.0434760520699117, 0.0438373840832296, 0.0677780113276634, 0.0550120052402667, 0.0169934001342453, 0.0337835907003681, 0.0638255852276804,
    0.0675453371162539, 0.0566853993371909, 0.0458910530352576, 0.0585652893733189, 0.0169101530818898, 0.0396699168759689, 0.0606637378715614, 0.0739828772730798, 0.0256383678542395, 0.0583481672209226, 0.0913167417218289, 0.0577604771612392, 0.0196307630730517, 0.0454814653806269, 0.0469369258950364, 0.0680145316241886, 0.0533988833170711, 0.0127352795010835, 0.0374512971313065, 0.063373336154884,
    0.0820752682977208, 0.0518533527904413, 0.0407987462008855, 0.0562541039269994, 0.0152355001122735, 0.036621233425206, 0.0660689578607331, 0.0683793167641103, 0.0212826750564448, 0.0591792135095524, 0.0941663464953813, 0.0573091151156363, 0.0219979756959186, 0.0389974623676506, 0.0498771425620675, 0.0669799056029993, 0.0590221723568093, 0.0109610362360464, 0.0288709253682642, 0.0740695502548593,
};


void Set_Neighbor_Rates(double NeighborRates[400], int type) {
    int i;

    if(type==RANDOM_FILL) {
		for(i=0; i<400; i++) { NeighborRates[i]=0.05; }
    } else if (type==XIA_FILL) {
		for(i=0; i<400; i++) { NeighborRates[i]=xiaNeighborRates[i]; }
    } else if (type==SP_FILL) {
		for(i=0; i<400; i++) { NeighborRates[i]=spNeighborRates[i]; }
    } else {
		fprintf(stderr,"Something wrong in Set_Neighbor_Rates, insert_freqs.c\n");
		exit(EXIT_FAILURE);
    }

}
