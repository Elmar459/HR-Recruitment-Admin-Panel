public class HrTextUtil {
    public static String toTitleCase(String value) {
        if (String.isBlank(value)) {
            return value;
        }
        List<String> words = new List<String>();
        for (String part : value.trim().toLowerCase().split('\\s+')) {
            words.add(part.left(1).toUpperCase() + part.substring(1));
        }
        return String.join(words, ' ');
    }

    public static String datedNumber(String prefix, Integer numberLength) {
        String datePart = Date.today().format().replace('/', '').replace('-', '');
        String sequence = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        while (sequence.length() < numberLength) {
            sequence = '0' + sequence;
        }
        return prefix + '-' + datePart + '-' + sequence.right(numberLength);
    }
}
