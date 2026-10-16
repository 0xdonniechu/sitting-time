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
    fact("🪑", "Ngồi liên tục nhiều giờ mỗi ngày liên quan đến tăng nguy cơ bệnh tim mạch và tiểu đường tuýp 2.", "Sitting for many hours a day is linked to a higher risk of heart disease and type 2 diabetes."),
    fact("🚶", "Đứng dậy đi lại vài phút mỗi 30–60 phút giúp cải thiện đường huyết sau bữa ăn.", "Getting up to walk for a few minutes every 30–60 minutes helps improve blood sugar after meals."),
    fact("🏃", "WHO khuyến nghị người lớn vận động cường độ vừa ít nhất 150 phút mỗi tuần.", "WHO recommends adults get at least 150 minutes of moderate activity a week."),
    fact("💪", "Tập sức mạnh ít nhất 2 buổi mỗi tuần giúp giữ khối cơ và xương chắc khỏe.", "Strength training at least twice a week helps keep your muscles and bones strong."),
    fact("👟", "Đi bộ nhanh đã là vận động cường độ vừa, không cần dụng cụ hay phòng tập.", "Brisk walking already counts as moderate exercise, with no equipment or gym needed."),
    fact("🪜", "Leo cầu thang là cách đơn giản để tăng nhịp tim trong ngày.", "Taking the stairs is an easy way to raise your heart rate during the day."),
    fact("😊", "Vận động thể chất giúp cải thiện tâm trạng và giảm cảm giác lo âu.", "Physical activity helps lift your mood and ease feelings of anxiety."),
    fact("🦵", "Ngồi lâu làm máu ở chân lưu thông chậm; co duỗi bắp chân giúp máu về tim tốt hơn.", "Long sitting slows blood flow in your legs; flexing your calves helps it return to the heart."),
    fact("✨", "WHO cho rằng vận động một chút vẫn tốt hơn không vận động gì.", "WHO says some physical activity is better than none."),
    fact("🌙", "Vận động đều đặn giúp dễ vào giấc và ngủ sâu hơn.", "Regular exercise helps you fall asleep faster and sleep more deeply."),
    fact("❤️", "Vận động thường xuyên giúp hạ huyết áp và tăng sức khỏe tim mạch.", "Regular activity helps lower blood pressure and strengthens your heart."),
    fact("🦴", "Đi bộ, leo cầu thang và các bài chịu trọng lượng cơ thể giúp xương chắc hơn.", "Walking, stair climbing and other weight-bearing exercise help build stronger bones."),
    fact("🧍", "Đứng cả ngày cũng không tốt; xen kẽ ngồi, đứng và đi lại mới là cách tốt nhất.", "Standing all day isn't ideal either; mixing sitting, standing and moving is best."),
    fact("📞", "Vừa nghe điện thoại vừa đi lại là cách dễ để bớt thời gian ngồi.", "Walking while you take a phone call is an easy way to cut sitting time."),
    fact("🌳", "Dành thời gian ở nơi có cây xanh giúp giảm căng thẳng.", "Spending time in green spaces helps reduce stress."),
    fact("🍽️", "Đi bộ nhẹ 10–15 phút sau bữa ăn giúp đường huyết tăng ít hơn.", "A light 10–15 minute walk after a meal helps limit the rise in blood sugar."),
    fact("🫀", "Chỉ vài phút vận động mạnh như leo cầu thang nhanh cũng có lợi cho tim.", "Even a few minutes of vigorous activity, like climbing stairs fast, benefits your heart."),
    fact("🪴", "Tưới cây, dọn bàn, đi lấy nước: việc nhỏ nào khiến bạn đứng dậy cũng có ích.", "Watering plants, tidying up, refilling water: any small task that gets you up helps."),
    // Stretching and posture
    fact("🙆", "Giãn cơ nhẹ nhàng giúp giảm căng cứng ở cổ, vai và lưng khi ngồi lâu.", "Gentle stretching eases stiffness in your neck, shoulders and back after long sitting."),
    fact("🧘", "Giữ mỗi động tác giãn cơ khoảng 15–30 giây, không nhún và không cố đến mức đau.", "Hold each stretch for about 15–30 seconds, without bouncing or pushing into pain."),
    fact("🖥️", "Màn hình nên ngang hoặc thấp hơn tầm mắt một chút để cổ không phải cúi.", "Keep your screen at or slightly below eye level so your neck doesn't bend forward."),
    fact("📱", "Cúi đầu nhìn điện thoại làm lực đè lên cổ tăng lên nhiều lần.", "Bending your head down to look at a phone puts several times more load on your neck."),
    fact("🔄", "Xoay vai ra sau vài vòng giúp giảm căng ở vai và lưng trên.", "Rolling your shoulders back a few times relieves tension in your shoulders and upper back."),
    fact("🦶", "Đặt cả hai bàn chân chạm sàn khi ngồi giúp lưng giữ tư thế ổn định.", "Keeping both feet flat on the floor while sitting helps keep your back stable."),
    fact("🖐️", "Duỗi các ngón tay và xoay cổ tay giúp giảm mỏi khi gõ phím lâu.", "Stretching your fingers and wrists eases strain from long typing sessions."),
    fact("🔁", "Thay đổi tư thế thường xuyên quan trọng hơn cố ngồi thẳng tuyệt đối.", "Changing position often matters more than sitting perfectly straight."),
    fact("🤸", "Ngồi lâu làm cơ gập hông bị co rút; động tác bước chùng chân giúp giãn chúng.", "Long sitting tightens your hip flexors; a lunge stretch helps loosen them."),
    fact("🙌", "Vươn hai tay lên cao và hít sâu giúp mở lồng ngực sau khi ngồi khom.", "Reaching both arms overhead with a deep breath opens your chest after slouching."),
    // Eyes
    fact("👀", "Quy tắc 20-20-20: cứ 20 phút, nhìn xa khoảng 6 mét trong 20 giây.", "The 20-20-20 rule: every 20 minutes, look about 20 feet (6 m) away for 20 seconds."),
    fact("😑", "Khi nhìn màn hình ta chớp mắt ít hơn bình thường, nên mắt dễ bị khô.", "We blink less when looking at screens, which can leave our eyes dry."),
    fact("💡", "Để độ sáng màn hình gần với ánh sáng trong phòng giúp mắt bớt mỏi.", "Matching screen brightness to the room's light reduces eye strain."),
    fact("📏", "Đặt màn hình cách mắt khoảng một sải tay giúp mắt bớt phải điều tiết.", "Placing your screen about an arm's length away eases your eyes' focusing effort."),
    fact("🌤️", "Trẻ em dành nhiều thời gian ngoài trời có nguy cơ cận thị thấp hơn.", "Children who spend more time outdoors have a lower risk of nearsightedness."),
    // Water
    fact("💧", "Nước chiếm khoảng 50–60% trọng lượng cơ thể người trưởng thành.", "Water makes up about 50–60% of an adult's body weight."),
    fact("🤕", "Thiếu nước nhẹ cũng có thể làm giảm khả năng tập trung và gây đau đầu.", "Even mild dehydration can lower your concentration and cause headaches."),
    fact("🚰", "Nước tiểu màu vàng nhạt là dấu hiệu bạn đang uống đủ nước.", "Pale yellow urine is a good sign you're drinking enough water."),
    fact("🥛", "Uống nước rải đều trong ngày tốt hơn đợi khát rồi uống thật nhiều một lần.", "Sipping water through the day is better than waiting until you're thirsty and gulping a lot."),
    fact("🍉", "Khoảng 20% lượng nước mỗi ngày đến từ thức ăn như rau và trái cây.", "About 20% of your daily water comes from food such as fruit and vegetables."),
    fact("🌅", "Một ly nước sau khi ngủ dậy giúp bù lượng nước mất qua hơi thở và mồ hôi ban đêm.", "A glass of water after waking replaces fluid lost through breath and sweat overnight."),
    fact("💦", "Nước lọc là lựa chọn tốt nhất; đồ uống có đường thêm calo mà không làm no.", "Plain water is the best choice; sugary drinks add calories without filling you up."),
    fact("🥵", "Khi vận động hoặc trời nóng, cơ thể cần nhiều nước hơn bình thường.", "You need more water than usual when exercising or in hot weather."),
    fact("🍶", "Để sẵn bình nước trên bàn giúp bạn nhớ uống nước thường xuyên hơn.", "Keeping a water bottle on your desk reminds you to drink more often."),
    fact("☕", "Cà phê và trà uống ở mức vừa phải cũng được tính vào lượng nước mỗi ngày.", "Coffee and tea in moderation also count toward your daily fluids."),
    // Food and nutrition
    fact("🥦", "WHO khuyến nghị ăn ít nhất 400 g rau và trái cây mỗi ngày.", "WHO recommends eating at least 400 g of fruit and vegetables a day."),
    fact("🧂", "WHO khuyến nghị người lớn ăn dưới 5 g muối mỗi ngày, khoảng một thìa cà phê.", "WHO recommends adults eat less than 5 g of salt a day, about one teaspoon."),
    fact("🍬", "WHO khuyên đường tự do nên dưới 10% năng lượng mỗi ngày, tốt nhất là dưới 5%.", "WHO advises keeping free sugars under 10% of daily energy, ideally under 5%."),
    fact("🌾", "Gạo lứt, yến mạch và ngũ cốc nguyên hạt chứa nhiều chất xơ hơn ngũ cốc tinh chế.", "Brown rice, oats and other whole grains contain more fiber than refined grains."),
    fact("🥬", "Chất xơ giúp tiêu hóa tốt và giữ cảm giác no lâu hơn.", "Fiber aids digestion and helps you feel full for longer."),
    fact("🐟", "Cá béo như cá hồi, cá thu cung cấp omega-3 có lợi cho tim.", "Oily fish like salmon and mackerel provide omega-3 fats that are good for your heart."),
    fact("🥜", "Một nắm nhỏ các loại hạt là món ăn vặt giàu chất béo tốt.", "A small handful of nuts is a snack rich in healthy fats."),
    fact("🌈", "Ăn rau củ nhiều màu giúp cơ thể nhận được nhiều loại vitamin và chất chống oxy hóa hơn.", "Eating vegetables of many colors gives you a wider range of vitamins and antioxidants."),
    fact("🍳", "Bữa sáng có chất đạm giúp no lâu hơn bữa sáng chỉ có tinh bột.", "A breakfast with protein keeps you full longer than one with only carbs."),
    fact("🌭", "Ăn nhiều thịt chế biến sẵn như xúc xích, thịt xông khói làm tăng nguy cơ ung thư đại trực tràng.", "Eating a lot of processed meat like sausage and bacon raises the risk of colorectal cancer."),
    fact("🫒", "Thay mỡ động vật bằng dầu thực vật như dầu ô liu có lợi cho tim mạch.", "Replacing animal fats with plant oils like olive oil is better for your heart."),
    fact("🍌", "Chuối, khoai lang và rau lá xanh giàu kali, giúp cân bằng tác động của muối lên huyết áp.", "Bananas, sweet potatoes and leafy greens are rich in potassium, which offsets salt's effect on blood pressure."),
    fact("🍊", "Vitamin C trong trái cây giúp cơ thể hấp thu sắt từ thực vật tốt hơn.", "Vitamin C from fruit helps your body absorb iron from plant foods."),
    fact("🧀", "Sữa, sữa chua, đậu phụ và cá nhỏ ăn cả xương là nguồn canxi tốt cho xương.", "Milk, yogurt, tofu and small fish eaten with their bones are good sources of calcium."),
    fact("🥣", "Sữa chua có men sống chứa vi khuẩn có lợi cho đường ruột.", "Yogurt with live cultures contains bacteria that support your gut."),
    fact("🍟", "Đồ chiên ngập dầu nhiều calo; luộc, hấp, nướng là những cách nấu nhẹ hơn.", "Deep-fried food is high in calories; boiling, steaming and grilling are lighter choices."),
    fact("🍺", "Theo WHO, không có mức uống rượu bia nào được coi là an toàn cho sức khỏe.", "According to WHO, no level of alcohol is considered safe for health."),
    fact("🥤", "Một lon nước ngọt 330 ml có thể chứa khoảng 35 g đường, gần 9 thìa cà phê.", "A 330 ml can of soda can hold about 35 g of sugar, nearly 9 teaspoons."),
    fact("🍎", "Ăn trái cây nguyên quả tốt hơn uống nước ép vì giữ được chất xơ.", "Whole fruit is better than juice because it keeps the fiber."),
    fact("🌱", "Các loại đậu là nguồn đạm thực vật rẻ và giàu chất xơ.", "Beans and lentils are a cheap source of plant protein and fiber."),
    fact("🥗", "Hãy để rau và trái cây chiếm khoảng một nửa đĩa ăn.", "Aim to fill about half your plate with vegetables and fruit."),
    fact("🥚", "Trứng là nguồn đạm chất lượng cao với giá phải chăng.", "Eggs are an affordable, high-quality source of protein."),
    // Eating habits
    fact("🐢", "Ăn chậm giúp não có thời gian nhận tín hiệu no, nên ít khi ăn quá nhiều.", "Eating slowly gives your brain time to register fullness, so you're less likely to overeat."),
    fact("📺", "Vừa ăn vừa xem màn hình dễ khiến ta ăn nhiều hơn mà không để ý.", "Eating in front of a screen makes it easy to eat more without noticing."),
    fact("😋", "Nhai kỹ giúp tiêu hóa dễ hơn và thưởng thức bữa ăn trọn vẹn hơn.", "Chewing thoroughly makes digestion easier and lets you enjoy your meal more."),
    fact("🛌", "Ăn no ngay trước khi ngủ dễ gây trào ngược; nên ăn tối trước giờ ngủ 2–3 tiếng.", "A big meal right before bed can cause reflux; finish dinner 2–3 hours before sleeping."),
    fact("🥕", "Để sẵn trái cây, hạt làm đồ ăn vặt giúp bạn tránh các món nhiều đường.", "Keeping fruit and nuts nearby as snacks helps you skip sugary ones."),
    fact("🧾", "Đọc nhãn dinh dưỡng giúp nhận ra đường và muối ẩn trong thực phẩm đóng gói.", "Reading nutrition labels reveals the hidden sugar and salt in packaged food."),
    fact("⏰", "Ăn đúng bữa đều đặn giúp tránh đói cồn cào rồi ăn quá nhiều về sau.", "Regular mealtimes help prevent extreme hunger and overeating later."),
    // Sleep
    fact("😴", "Người trưởng thành cần ngủ ít nhất 7 tiếng mỗi đêm.", "Adults need at least 7 hours of sleep a night."),
    fact("🕰️", "Ngủ và thức dậy cùng giờ mỗi ngày, kể cả cuối tuần, giúp đồng hồ sinh học ổn định.", "Going to bed and waking at the same time every day, weekends included, steadies your body clock."),
    fact("📵", "Ánh sáng màn hình trước giờ ngủ có thể làm chậm tiết melatonin, khiến khó ngủ hơn.", "Screen light before bed can delay melatonin and make it harder to fall asleep."),
    fact("🫖", "Caffeine có thể còn tác dụng 6 tiếng hoặc lâu hơn; bớt cà phê buổi chiều giúp ngủ ngon hơn.", "Caffeine can stay active for 6 hours or more; cutting it in the afternoon helps you sleep."),
    fact("🌡️", "Phòng ngủ mát, tối và yên tĩnh giúp ngủ sâu hơn.", "A cool, dark and quiet bedroom supports deeper sleep."),
    fact("🧠", "Trong lúc ngủ, não củng cố trí nhớ và những gì bạn học được trong ngày.", "While you sleep, your brain consolidates memories and what you learned that day."),
    fact("🥱", "Thiếu ngủ kéo dài liên quan đến tăng nguy cơ béo phì, tiểu đường và bệnh tim.", "Long-term short sleep is linked to higher risk of obesity, diabetes and heart disease."),
    fact("💤", "Ngủ trưa ngắn 10–20 phút giúp tỉnh táo mà không bị uể oải khi dậy.", "A short 10–20 minute nap boosts alertness without leaving you groggy."),
    fact("🍷", "Rượu có thể làm bạn dễ buồn ngủ nhưng khiến nửa đêm về sáng ngủ chập chờn hơn.", "Alcohol may make you drowsy but disrupts sleep in the second half of the night."),
    fact("🛏️", "Nằm 20 phút chưa ngủ được thì hãy dậy làm việc nhẹ nhàng, buồn ngủ rồi quay lại giường.", "Can't sleep after 20 minutes? Get up, do something calm, and return to bed when sleepy."),
    // Sunlight
    fact("☀️", "Ánh nắng buổi sáng giúp chỉnh đồng hồ sinh học, tối đến dễ ngủ hơn.", "Morning daylight helps set your body clock, so it's easier to sleep at night."),
    fact("🌞", "Da tạo ra vitamin D khi tiếp xúc với ánh nắng.", "Your skin makes vitamin D when exposed to sunlight."),
    fact("🧴", "Tia UV mạnh nhất khoảng từ 10 giờ sáng đến 4 giờ chiều; hãy che chắn khi ra nắng lâu.", "UV rays are strongest from about 10 a.m. to 4 p.m.; cover up during long sun exposure."),
    fact("🪟", "Ngồi làm việc gần cửa sổ có ánh sáng tự nhiên giúp tỉnh táo hơn ban ngày.", "Working near a window with daylight helps you stay alert during the day."),
    fact("🕶️", "Kính râm chống tia UV giúp bảo vệ mắt khi ra ngoài nắng.", "UV-blocking sunglasses protect your eyes outdoors."),
    fact("☁️", "Tia UV vẫn có thể làm hại da kể cả vào ngày nhiều mây.", "UV rays can still harm your skin on cloudy days."),
    // Breathing, mind and habits
    fact("🌬️", "Hít thở chậm và sâu bằng bụng vài phút giúp cơ thể bớt căng thẳng.", "A few minutes of slow, deep belly breathing helps calm your body."),
    fact("🫁", "Thở ra dài hơn hít vào giúp cơ thể chuyển sang trạng thái thư giãn.", "Breathing out longer than you breathe in helps your body relax."),
    fact("🙏", "Viết ra vài điều bạn biết ơn mỗi ngày có thể giúp cải thiện tâm trạng.", "Writing down a few things you're grateful for each day can lift your mood."),
    fact("🤝", "Các mối quan hệ xã hội tốt liên quan đến sức khỏe tốt hơn và sống lâu hơn.", "Strong social connections are linked to better health and a longer life."),
    fact("🚭", "Bỏ thuốc lá ở bất kỳ tuổi nào cũng giúp giảm nguy cơ bệnh tim và phổi.", "Quitting smoking at any age lowers your risk of heart and lung disease."),
    fact("🧼", "Rửa tay bằng xà phòng ít nhất 20 giây giúp ngăn nhiều bệnh lây nhiễm.", "Washing your hands with soap for at least 20 seconds prevents many infections."),
    fact("🦷", "Đánh răng 2 lần mỗi ngày với kem có fluor giúp ngừa sâu răng.", "Brushing twice a day with fluoride toothpaste helps prevent tooth decay."),
    fact("🎧", "Nghe tai nghe âm lượng lớn trong thời gian dài có thể làm hại thính lực vĩnh viễn.", "Listening loudly on headphones for long periods can permanently damage your hearing."),
    fact("🍅", "Làm việc theo từng khối thời gian có nghỉ xen kẽ giúp giữ tập trung lâu hơn.", "Working in focused blocks with breaks in between helps you stay focused longer."),
    fact("🔕", "Tắt các thông báo không cần thiết giúp bớt bị gián đoạn và giữ tập trung.", "Turning off unneeded notifications cuts interruptions and protects your focus."),
    fact("😂", "Cười giúp giảm căng thẳng ngay lập tức.", "Laughing gives quick relief from stress."),
    fact("🧘‍♀️", "Thiền chánh niệm đều đặn có thể giúp giảm căng thẳng và lo âu.", "Regular mindfulness meditation can help reduce stress and anxiety."),
    fact("📐", "Vòng eo lớn là dấu hiệu mỡ bụng, liên quan đến nguy cơ bệnh tim và tiểu đường.", "A large waistline signals belly fat, which is linked to heart disease and diabetes."),
    fact("🩺", "Khám sức khỏe định kỳ giúp phát hiện sớm cao huyết áp, tiểu đường và nhiều bệnh khác.", "Regular check-ups catch high blood pressure, diabetes and other conditions early."),
    fact("🎯", "Thói quen nhỏ lặp lại mỗi ngày dễ duy trì hơn một thay đổi lớn.", "Small habits repeated daily are easier to keep than one big change."),
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
