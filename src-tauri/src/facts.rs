use serde::Serialize;
use std::{
    collections::hash_map::RandomState,
    hash::{BuildHasher, Hasher},
};

/// One short health fact shown on the full-screen reminder, in Vietnamese and English.
#[derive(Debug, PartialEq, Serialize)]
pub struct HealthFact {
    pub emoji: &'static str,
    pub vi: &'static str,
    pub en: &'static str,
}

const fn fact(emoji: &'static str, vi: &'static str, en: &'static str) -> HealthFact {
    HealthFact { emoji, vi, en }
}

pub const FACTS: &[HealthFact] = &[
    // Sitting and movement
    fact("🪑", "Ngồi trên 8 tiếng mỗi ngày mà ít vận động liên quan đến nguy cơ tử vong sớm cao hơn tới 59% (Lancet, 2016).", "Sitting over 8 hours a day with little activity is linked to up to 59% higher risk of early death (Lancet, 2016)."),
    fact("⏱️", "60–75 phút vận động vừa mỗi ngày gần như xóa được nguy cơ tăng thêm do ngồi lâu (Lancet, 2016).", "60–75 minutes of moderate activity a day appears to cancel out the extra risk of long sitting (Lancet, 2016)."),
    fact("🚶", "Cứ 30 phút ngồi, đi bộ nhẹ 5 phút giúp giảm 58% mức tăng đường huyết sau ăn (ĐH Columbia, 2023).", "A 5-minute light walk every 30 minutes of sitting cut blood sugar spikes after meals by 58% (Columbia, 2023)."),
    fact("🔄", "Thay 30 phút ngồi bằng 30 phút vận động nhẹ liên quan đến giảm 17% nguy cơ tử vong sớm (2019).", "Swapping 30 minutes of sitting for light activity is linked to 17% lower risk of early death (2019)."),
    fact("🏃", "WHO khuyến nghị người lớn vận động vừa 150–300 phút hoặc vận động mạnh 75–150 phút mỗi tuần.", "WHO recommends adults get 150–300 minutes of moderate or 75–150 minutes of vigorous activity a week."),
    fact("✨", "Chỉ 11 phút đi bộ nhanh mỗi ngày (75 phút/tuần) liên quan đến giảm 23% nguy cơ tử vong sớm (2023).", "Just 11 minutes of brisk walking a day (75 min/week) is linked to 23% lower risk of early death (2023)."),
    fact("💪", "Tập sức mạnh 30–60 phút mỗi tuần liên quan đến giảm 10–20% nguy cơ tử vong sớm (BJSM, 2022).", "30–60 minutes of strength training a week is linked to 10–20% lower risk of early death (BJSM, 2022)."),
    fact("👟", "Với người dưới 60 tuổi, lợi ích sống lâu tăng dần đến khoảng 8.000–10.000 bước mỗi ngày (Lancet, 2022).", "For adults under 60, the longevity benefit keeps rising up to about 8,000–10,000 steps a day (Lancet, 2022)."),
    fact("🦶", "Đi bộ khoảng 100 bước mỗi phút đã đạt cường độ vận động vừa.", "Walking at about 100 steps per minute already counts as moderate-intensity activity."),
    fact("🪜", "Leo trên 5 tầng cầu thang (khoảng 50 bậc) mỗi ngày liên quan đến giảm 20% nguy cơ bệnh tim mạch (2023).", "Climbing more than 5 flights of stairs (about 50 steps) a day is linked to 20% lower heart disease risk (2023)."),
    fact("🫀", "3 lần vận động mạnh 1–2 phút mỗi ngày, như leo cầu thang nhanh, liên quan đến giảm khoảng 40% nguy cơ tử vong sớm.", "Three 1–2 minute bursts of vigorous activity a day, like fast stair climbing, are linked to about 40% lower risk of early death."),
    fact("😊", "Đi bộ nhanh 2,5 giờ mỗi tuần liên quan đến giảm 25% nguy cơ trầm cảm (JAMA Psychiatry, 2022).", "2.5 hours of brisk walking a week is linked to 25% lower risk of depression (JAMA Psychiatry, 2022)."),
    fact("🌙", "Vận động 150 phút mỗi tuần giúp chất lượng giấc ngủ cải thiện khoảng 65% (Oregon State, 2011).", "150 minutes of activity a week improved sleep quality by about 65% (Oregon State, 2011)."),
    fact("❤️", "Tập aerobic đều đặn giúp hạ huyết áp tâm thu khoảng 5–8 mmHg ở người cao huyết áp.", "Regular aerobic exercise lowers systolic blood pressure by about 5–8 mmHg in people with hypertension."),
    fact("🦴", "Khối xương đạt đỉnh vào khoảng 30 tuổi rồi giảm dần; đi bộ và tập chịu lực giúp làm chậm quá trình này.", "Bone mass peaks around age 30 and then declines; walking and weight-bearing exercise slow the loss."),
    fact("🧍", "ĐH Cornell gợi ý mỗi 30 phút làm việc: ngồi 20 phút, đứng 8 phút và đi lại 2 phút.", "Cornell University suggests each 30 minutes of work: sit for 20, stand for 8 and move for 2."),
    fact("📞", "Vừa nghe một cuộc gọi 10 phút vừa đi lại là thêm khoảng 800–1.000 bước chân.", "Pacing during a 10-minute phone call adds roughly 800–1,000 steps."),
    fact("🌳", "Dành ít nhất 120 phút mỗi tuần ở nơi có thiên nhiên liên quan đến sức khỏe và tinh thần tốt hơn (2019).", "Spending at least 120 minutes a week in nature is linked to better health and wellbeing (2019)."),
    fact("🍽️", "Chỉ cần đi bộ nhẹ 2–5 phút sau bữa ăn đã giúp giảm mức tăng đường huyết (tổng hợp 7 nghiên cứu, 2022).", "Even a light 2–5 minute walk after a meal lowers the blood sugar rise (review of 7 studies, 2022)."),
    fact("🧹", "Dọn dẹp nhà cửa 1 giờ đốt khoảng 200 kcal với người nặng 70 kg.", "An hour of housecleaning burns about 200 kcal for a 70 kg person."),
    // Stretching and posture
    fact("🙆", "Chỉ 2 phút tập cổ vai với dây kháng lực mỗi ngày đã giúp giảm đau cổ vai ở nhân viên văn phòng (2011).", "Just 2 minutes a day of neck and shoulder exercise with a resistance band eased office workers' pain (2011)."),
    fact("🧘", "Giữ mỗi động tác giãn cơ 10–30 giây, lặp lại 2–4 lần, không nhún và không cố đến mức đau.", "Hold each stretch for 10–30 seconds and repeat it 2–4 times, without bouncing or pushing into pain."),
    fact("🖥️", "Mép trên màn hình nên ngang hoặc thấp hơn tầm mắt; tâm màn hình thấp hơn mắt khoảng 15–20°.", "The top of your screen should be at or below eye level, with its centre about 15–20° below your eyes."),
    fact("📏", "Đặt màn hình cách mắt khoảng 50–100 cm, màn hình càng lớn thì đặt càng xa.", "Place your screen about 50–100 cm from your eyes, farther for a larger screen."),
    fact("📱", "Đầu nặng khoảng 5 kg; khi cúi 60° nhìn điện thoại, lực đè lên cổ tăng lên khoảng 27 kg.", "Your head weighs about 5 kg; tilting it 60° to look at a phone puts about 27 kg of load on your neck."),
    fact("🔃", "Xoay vai ra sau 10 vòng mỗi giờ giúp giảm căng cứng ở vai và lưng trên.", "Rolling your shoulders back 10 times every hour eases stiffness in your shoulders and upper back."),
    fact("🪑", "Khi ngồi, đầu gối nên gập khoảng 90° và hai bàn chân đặt phẳng trên sàn.", "When seated, keep your knees bent at about 90° and both feet flat on the floor."),
    fact("🖐️", "Cứ mỗi giờ gõ phím, dành 30 giây duỗi ngón tay và xoay cổ tay để giảm mỏi.", "For every hour of typing, take 30 seconds to stretch your fingers and roll your wrists."),
    fact("🔁", "Đổi tư thế ít nhất mỗi 30 phút quan trọng hơn cố ngồi thẳng tuyệt đối.", "Changing position at least every 30 minutes matters more than sitting perfectly straight."),
    fact("🤸", "Bước chùng chân và giữ 30 giây mỗi bên giúp giãn cơ gập hông bị co rút do ngồi lâu.", "A lunge held for 30 seconds on each side loosens hip flexors tightened by long sitting."),
    fact("🙌", "Vươn hai tay lên cao và hít sâu 5 nhịp giúp mở lồng ngực sau khi ngồi khom.", "Reach both arms overhead and take 5 deep breaths to open your chest after slouching."),
    // Eyes
    fact("👀", "Quy tắc 20-20-20: cứ 20 phút, nhìn xa khoảng 6 mét trong 20 giây.", "The 20-20-20 rule: every 20 minutes, look about 20 feet (6 m) away for 20 seconds."),
    fact("😑", "Bình thường ta chớp mắt 15–20 lần mỗi phút; khi nhìn màn hình, số lần chớp mắt có thể giảm hơn một nửa.", "We normally blink 15–20 times a minute; looking at a screen can cut that by more than half."),
    fact("👓", "Mắt thường bắt đầu lão thị từ khoảng 40 tuổi; từ tuổi này nên khám mắt 1–2 năm một lần.", "Most eyes start losing near focus around age 40; from then on, get an eye exam every 1–2 years."),
    fact("🌤️", "Trẻ được ra ngoài trời thêm 40 phút mỗi ngày có tỷ lệ mắc cận thị mới thấp hơn khoảng 23% (JAMA, 2015).", "Children given 40 extra minutes outdoors a day had about 23% fewer new cases of myopia (JAMA, 2015)."),
    // Water
    fact("💧", "Nước chiếm khoảng 50–60% trọng lượng cơ thể người trưởng thành.", "Water makes up about 50–60% of an adult's body weight."),
    fact("🤕", "Mất nước chỉ 1–2% trọng lượng cơ thể đã có thể làm giảm khả năng tập trung và gây đau đầu.", "Losing just 1–2% of body weight in water can reduce concentration and cause headaches."),
    fact("🚰", "Người khỏe mạnh thường đi tiểu khoảng 6–7 lần mỗi ngày; nước tiểu vàng nhạt là dấu hiệu đủ nước.", "Healthy adults usually pee about 6–7 times a day; pale yellow urine means you're drinking enough."),
    fact("🥛", "EFSA khuyến nghị tổng lượng nước mỗi ngày khoảng 2 lít với nữ và 2,5 lít với nam, kể cả nước từ thức ăn.", "EFSA recommends about 2 litres of water a day for women and 2.5 litres for men, including water from food."),
    fact("🍉", "Khoảng 20% lượng nước mỗi ngày đến từ thức ăn; dưa hấu chứa tới 92% là nước.", "About 20% of your daily water comes from food; watermelon is 92% water."),
    fact("🌅", "Uống 1–2 ly nước (250–500 ml) sau khi ngủ dậy giúp bù lượng nước mất qua 7–8 tiếng ngủ.", "Drinking 1–2 glasses (250–500 ml) of water after waking replaces fluid lost over 7–8 hours of sleep."),
    fact("💦", "Thay một lon nước ngọt 330 ml bằng nước lọc là bớt khoảng 140 kcal và 35 g đường, gần 9 thìa cà phê.", "Swapping a 330 ml can of soda for water saves about 140 kcal and 35 g of sugar, nearly 9 teaspoons."),
    fact("🥵", "Khi tập luyện hoặc trời nóng, cơ thể có thể mất 0,5–2 lít mồ hôi mỗi giờ.", "During exercise or in hot weather, you can lose 0.5–2 litres of sweat an hour."),
    fact("🍶", "Một bình 500 ml rót đầy 4 lần mỗi ngày là khoảng 2 lít nước.", "Refilling a 500 ml bottle 4 times a day adds up to about 2 litres of water."),
    fact("☕", "Tối đa 400 mg caffeine mỗi ngày, khoảng 4 tách cà phê pha máy, được coi là an toàn với người lớn khỏe mạnh.", "Up to 400 mg of caffeine a day, about 4 cups of brewed coffee, is considered safe for healthy adults."),
    fact("⏳", "Uống 500 ml nước 30 phút trước bữa ăn giúp người thừa cân giảm thêm khoảng 1,3 kg sau 12 tuần (2015).", "Drinking 500 ml of water 30 minutes before meals helped overweight adults lose 1.3 kg more in 12 weeks (2015)."),
    // Food and nutrition
    fact("🥦", "WHO khuyến nghị ăn ít nhất 400 g rau và trái cây mỗi ngày, khoảng 5 phần.", "WHO recommends eating at least 400 g of fruit and vegetables a day, about 5 portions."),
    fact("🌈", "Ăn khoảng 800 g rau quả mỗi ngày liên quan đến giảm 31% nguy cơ tử vong sớm (2017).", "Eating about 800 g of fruit and vegetables a day is linked to 31% lower risk of early death (2017)."),
    fact("🧂", "WHO khuyến nghị dưới 5 g muối mỗi ngày; người Việt trung bình ăn khoảng 9,4 g, gần gấp đôi.", "WHO recommends under 5 g of salt a day; Vietnamese adults eat about 9.4 g on average, nearly double."),
    fact("🍬", "WHO khuyên đường tự do dưới 50 g mỗi ngày, tốt nhất là dưới 25 g, tức khoảng 6 thìa cà phê.", "WHO advises under 50 g of free sugars a day, ideally under 25 g, about 6 teaspoons."),
    fact("🌾", "Ăn 90 g ngũ cốc nguyên hạt mỗi ngày liên quan đến giảm 22% nguy cơ bệnh tim mạch (BMJ, 2016).", "Eating 90 g of whole grains a day is linked to 22% lower risk of cardiovascular disease (BMJ, 2016)."),
    fact("🥬", "Ăn 25–29 g chất xơ mỗi ngày liên quan đến giảm 15–30% nguy cơ tử vong và bệnh tim (Lancet, 2019).", "Eating 25–29 g of fiber a day is linked to 15–30% lower risk of death and heart disease (Lancet, 2019)."),
    fact("🐟", "Hội Tim mạch Mỹ khuyên ăn cá 2 lần mỗi tuần, ưu tiên cá béo như cá hồi, cá thu.", "The American Heart Association recommends fish twice a week, especially oily fish like salmon and mackerel."),
    fact("🥜", "Ăn 28 g các loại hạt mỗi ngày, khoảng một nắm nhỏ, liên quan đến giảm 21% nguy cơ bệnh tim mạch (2016).", "Eating 28 g of nuts a day, about a small handful, is linked to 21% lower heart disease risk (2016)."),
    fact("🍳", "Mỗi bữa có khoảng 25–30 g chất đạm giúp no lâu hơn và hỗ trợ giữ cơ bắp.", "Getting about 25–30 g of protein at each meal keeps you full longer and helps maintain muscle."),
    fact("🥚", "Một quả trứng gà khoảng 50 g chứa 6 g đạm chất lượng cao và chỉ khoảng 70 kcal.", "One 50 g egg has 6 g of high-quality protein and only about 70 kcal."),
    fact("🌭", "Mỗi 50 g thịt chế biến sẵn ăn mỗi ngày làm tăng 18% nguy cơ ung thư đại trực tràng (WHO/IARC).", "Every 50 g of processed meat eaten daily raises colorectal cancer risk by 18% (WHO/IARC)."),
    fact("🫒", "Dùng hơn 7 g dầu ô liu mỗi ngày, khoảng nửa thìa canh, liên quan đến giảm 19% nguy cơ tử vong sớm (2022).", "Using more than 7 g of olive oil a day, about half a tablespoon, is linked to 19% lower risk of early death (2022)."),
    fact("🍌", "WHO khuyến nghị ít nhất 3.510 mg kali mỗi ngày; một quả chuối cỡ vừa có khoảng 420 mg.", "WHO recommends at least 3,510 mg of potassium a day; a medium banana has about 420 mg."),
    fact("🍊", "Một quả cam (khoảng 70 mg vitamin C) ăn kèm bữa có thể giúp hấp thu sắt từ thực vật tăng khoảng gấp đôi.", "An orange (about 70 mg of vitamin C) with a meal can roughly double the iron you absorb from plant foods."),
    fact("🧀", "Người lớn cần khoảng 1.000 mg canxi mỗi ngày; một ly sữa 250 ml cung cấp khoảng 300 mg.", "Adults need about 1,000 mg of calcium a day; a 250 ml glass of milk provides about 300 mg."),
    fact("🦠", "Ruột người chứa khoảng 38 nghìn tỷ vi khuẩn, và chất xơ là thức ăn chính của chúng.", "Your gut holds about 38 trillion bacteria, and fiber is their main food."),
    fact("🍟", "Một thìa canh dầu ăn chứa khoảng 120 kcal; luộc, hấp thay vì chiên giúp bớt đáng kể calo.", "One tablespoon of cooking oil has about 120 kcal; boiling or steaming instead of frying saves a lot."),
    fact("🧈", "Mỗi gram chất béo cho 9 kcal, gấp hơn 2 lần đạm và tinh bột (4 kcal mỗi gram).", "Each gram of fat has 9 kcal, more than twice as much as protein or carbs (4 kcal per gram)."),
    fact("🍺", "Theo WHO, không có mức rượu bia nào an toàn; năm 2019 rượu bia gây ra 2,6 triệu ca tử vong.", "According to WHO, no level of alcohol is safe; it caused 2.6 million deaths in 2019."),
    fact("🥤", "Mỗi lon nước ngọt thêm mỗi ngày liên quan đến tăng khoảng 18% nguy cơ tiểu đường tuýp 2 (BMJ, 2015).", "Each extra daily serving of soda is linked to about 18% higher risk of type 2 diabetes (BMJ, 2015)."),
    fact("🍎", "Thay 3 ly nước ép mỗi tuần bằng trái cây nguyên quả liên quan đến giảm 7% nguy cơ tiểu đường tuýp 2 (BMJ, 2013).", "Replacing 3 glasses of fruit juice a week with whole fruit is linked to 7% lower type 2 diabetes risk (BMJ, 2013)."),
    fact("🌱", "100 g đậu lăng nấu chín có khoảng 9 g đạm và 8 g chất xơ.", "100 g of cooked lentils has about 9 g of protein and 8 g of fiber."),
    fact("🥗", "Đĩa ăn lành mạnh theo Harvard: 1/2 rau quả, 1/4 ngũ cốc nguyên hạt, 1/4 chất đạm.", "Harvard's healthy plate: 1/2 vegetables and fruit, 1/4 whole grains, 1/4 protein."),
    fact("🍏", "Một quả táo cỡ vừa chỉ khoảng 95 kcal nhưng có 4 g chất xơ, là món ăn vặt no lâu.", "A medium apple has only about 95 kcal but 4 g of fiber, a snack that keeps you full."),
    // Eating habits
    fact("🐢", "Não cần khoảng 20 phút để nhận tín hiệu no; ăn chậm giúp tránh ăn quá nhiều.", "Your brain needs about 20 minutes to register fullness; eating slowly helps you avoid overeating."),
    fact("😋", "Nhai mỗi miếng khoảng 20–30 lần trước khi nuốt giúp tiêu hóa dễ hơn và ăn chậm lại.", "Chewing each bite about 20–30 times before swallowing eases digestion and slows your eating."),
    fact("🛌", "Ăn tối xong trước giờ ngủ 2–3 tiếng giúp giảm trào ngược và ngủ ngon hơn.", "Finishing dinner 2–3 hours before bed reduces reflux and helps you sleep."),
    fact("🧾", "Trên nhãn dinh dưỡng, 4 g đường bằng 1 thìa cà phê, 1 g natri bằng khoảng 2,5 g muối.", "On a nutrition label, 4 g of sugar is 1 teaspoon and 1 g of sodium is about 2.5 g of salt."),
    // Sleep
    fact("😴", "Người trưởng thành cần ngủ 7–9 tiếng mỗi đêm.", "Adults need 7–9 hours of sleep a night."),
    fact("🕰️", "Người ngủ dậy đúng giờ đều đặn nhất có nguy cơ tử vong sớm thấp hơn 20–48% so với người thất thường nhất (2024).", "People with the most regular sleep times had 20–48% lower risk of early death than the least regular (2024)."),
    fact("📵", "Đọc trên máy tính bảng trước khi ngủ làm melatonin giảm khoảng 55% và tiết chậm hơn 1,5 giờ so với sách giấy.", "Reading on a tablet before bed cut melatonin by about 55% and delayed it by 1.5 hours versus a paper book."),
    fact("🫖", "Caffeine có thời gian bán thải khoảng 5 giờ: ly cà phê lúc 15h vẫn còn một nửa tác dụng lúc 20h.", "Caffeine has a half-life of about 5 hours: half of a 3 p.m. coffee is still active at 8 p.m."),
    fact("🌡️", "Phòng ngủ ở khoảng 16–19°C thường giúp ngủ sâu hơn.", "A bedroom at about 16–19°C usually supports deeper sleep."),
    fact("🧠", "Thức trắng một đêm làm khả năng ghi nhớ thông tin mới giảm khoảng 40%.", "One night without sleep cuts your ability to form new memories by about 40%."),
    fact("🥱", "Thường xuyên ngủ dưới 6 tiếng mỗi đêm liên quan đến tăng 12% nguy cơ tử vong sớm (2010).", "Regularly sleeping under 6 hours a night is linked to 12% higher risk of early death (2010)."),
    fact("💤", "Ngủ trưa ngắn 10–20 phút giúp tỉnh táo mà không bị uể oải khi dậy.", "A short 10–20 minute nap boosts alertness without leaving you groggy."),
    fact("🍷", "Uống nhiều rượu bia trước khi ngủ làm chất lượng phục hồi của giấc ngủ giảm khoảng 39% (2018).", "Heavy drinking before bed lowered the restorative quality of sleep by about 39% (2018)."),
    fact("🛏️", "Nằm 20 phút chưa ngủ được thì hãy dậy làm việc nhẹ nhàng, buồn ngủ rồi quay lại giường.", "Can't sleep after 20 minutes? Get up, do something calm, and return to bed when sleepy."),
    // Sunlight
    fact("☀️", "Ngoài trời ngày âm u vẫn sáng khoảng 10.000 lux, gấp hơn 20 lần đèn trong phòng (300–500 lux).", "Outdoors on an overcast day is about 10,000 lux, over 20 times brighter than indoor lighting (300–500 lux)."),
    fact("🌞", "Phơi nắng 5–30 phút, ít nhất 2 lần mỗi tuần, thường đủ để da tạo vitamin D.", "5–30 minutes of sun at least twice a week is usually enough for your skin to make vitamin D."),
    fact("🧴", "Khi chỉ số UV từ 3 trở lên, WHO khuyên che chắn da; tia UV thường mạnh nhất từ 10h đến 16h.", "When the UV index is 3 or higher, WHO advises sun protection; UV is usually strongest from 10 a.m. to 4 p.m."),
    fact("🪟", "Nhân viên làm việc gần cửa sổ ngủ nhiều hơn khoảng 46 phút mỗi đêm so với người không có ánh sáng tự nhiên (2014).", "Office workers near windows slept about 46 minutes more a night than those without daylight (2014)."),
    fact("🕶️", "Kính râm nên chặn được 99–100% tia UVA và UVB.", "Sunglasses should block 99–100% of UVA and UVB rays."),
    fact("☁️", "Mây có thể để lọt tới 80% tia UV, nên ngày âm u vẫn có thể bị cháy nắng.", "Clouds can let through up to 80% of UV rays, so you can still burn on a cloudy day."),
    // Breathing, mind and habits
    fact("🌬️", "Thở chậm khoảng 6 nhịp mỗi phút trong 5 phút giúp nhịp tim và cơ thể dịu lại.", "Breathing slowly at about 6 breaths a minute for 5 minutes calms your heart rate and body."),
    fact("🫁", "5 phút thở dài theo chu kỳ mỗi ngày (hít 2 lần, thở ra thật dài) cải thiện tâm trạng nhiều hơn thiền (Stanford, 2023).", "5 minutes a day of cyclic sighing (two inhales, one long exhale) lifted mood more than meditation (Stanford, 2023)."),
    fact("🙏", "Viết ra 3 điều tốt đẹp mỗi tối trong 1 tuần giúp tăng hạnh phúc kéo dài tới 6 tháng (2005).", "Writing down 3 good things each evening for one week raised happiness for up to 6 months (2005)."),
    fact("🤝", "Người có các mối quan hệ xã hội tốt có khả năng sống lâu hơn khoảng 50% (tổng hợp 148 nghiên cứu, 2010).", "People with strong social ties have about 50% higher odds of survival (review of 148 studies, 2010)."),
    fact("🚭", "Sau 1 năm bỏ thuốc lá, nguy cơ bệnh mạch vành giảm còn khoảng một nửa so với người vẫn hút.", "One year after quitting smoking, your risk of coronary heart disease is about half that of a smoker."),
    fact("🧼", "Rửa tay bằng xà phòng ít nhất 20 giây giúp giảm 23–40% bệnh tiêu chảy (CDC).", "Washing your hands with soap for at least 20 seconds cuts diarrhoeal illness by 23–40% (CDC)."),
    fact("🦷", "Đánh răng 2 lần mỗi ngày, mỗi lần 2 phút, với kem đánh răng có fluor.", "Brush your teeth twice a day for 2 minutes each time, with fluoride toothpaste."),
    fact("🎧", "Theo WHO, nghe ở mức 80 dB chỉ an toàn tối đa khoảng 40 giờ mỗi tuần; to hơn thì thời gian an toàn giảm nhanh.", "According to WHO, 80 dB is safe for only about 40 hours a week; louder sound shortens that quickly."),
    fact("🍅", "Pomodoro: tập trung 25 phút rồi nghỉ 5 phút; sau 4 lượt thì nghỉ dài 15–30 phút.", "Pomodoro: focus for 25 minutes, then rest for 5; after 4 rounds, take a 15–30 minute break."),
    fact("🔕", "Sau khi bị gián đoạn, trung bình mất khoảng 23 phút để quay lại công việc ban đầu (UC Irvine).", "After an interruption, it takes about 23 minutes on average to get back to the original task (UC Irvine)."),
    fact("😂", "Cười 10–15 phút mỗi ngày đốt thêm khoảng 10–40 kcal (ĐH Vanderbilt).", "Laughing for 10–15 minutes a day burns an extra 10–40 kcal (Vanderbilt University)."),
    fact("🧘‍♀️", "Khóa tập thiền chánh niệm 8 tuần giúp giảm lo âu và trầm cảm ở mức vừa phải (JAMA, 2014).", "An 8-week mindfulness meditation program moderately reduces anxiety and depression (JAMA, 2014)."),
    fact("📐", "Với người châu Á, vòng eo từ 90 cm (nam) hoặc 80 cm (nữ) là dấu hiệu mỡ bụng có hại.", "For Asian adults, a waist of 90 cm or more (men) or 80 cm or more (women) signals harmful belly fat."),
    fact("🩺", "Nên đo huyết áp ít nhất mỗi năm một lần; huyết áp bình thường là dưới 120/80 mmHg.", "Check your blood pressure at least once a year; normal is below 120/80 mmHg."),
    fact("🎯", "Trung bình mất khoảng 66 ngày để một thói quen mới trở thành tự động (2010).", "On average it takes about 66 days for a new habit to become automatic (2010)."),
];

/// Picks a fact at random. `RandomState` is seeded by the OS, so this needs no
/// extra crate and nothing to persist; an occasional repeat is fine.
pub fn pick() -> &'static HealthFact {
    let random = RandomState::new().build_hasher().finish();
    &FACTS[(random % FACTS.len() as u64) as usize]
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;

    /// Longer text no longer fits the reminder card on a small screen.
    const MAX_CHARS: usize = 130;

    #[test]
    fn there_are_about_a_hundred_facts() {
        assert!(FACTS.len() >= 100, "only {} facts", FACTS.len());
    }

    #[test]
    fn every_fact_is_filled_in_and_short() {
        for fact in FACTS {
            assert!(!fact.emoji.is_empty() && !fact.vi.is_empty() && !fact.en.is_empty());
            assert!(fact.vi.chars().count() <= MAX_CHARS, "too long: {}", fact.vi);
            assert!(fact.en.chars().count() <= MAX_CHARS, "too long: {}", fact.en);
        }
    }

    #[test]
    fn no_fact_appears_twice() {
        let vi: HashSet<_> = FACTS.iter().map(|fact| fact.vi).collect();
        let en: HashSet<_> = FACTS.iter().map(|fact| fact.en).collect();
        assert_eq!(vi.len(), FACTS.len());
        assert_eq!(en.len(), FACTS.len());
    }

    #[test]
    fn pick_varies() {
        let picked: HashSet<_> = (0..200).map(|_| pick().en).collect();
        assert!(picked.len() > 1);
    }
}
