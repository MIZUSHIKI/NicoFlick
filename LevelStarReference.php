<?php

/**
 * NicoFlickDB形式のノーツ文字列から参考難易度を実数で返す（上限なし）。
 *
 * 計算仕様バージョン: ver.2.0
 * - ver.1.0: 四捨五入し、上限20の整数を返す。
 * - ver.2.0:
 *   ・星8〜20に相当する難易度の計算式を調整。
 *   ・丸め前の実数を上限なしで返す形式に変更。
 *   ・整数化・上限20への制限は呼び出し側で行う。
 *   ・星1〜7を旧式で求める仕様は維持。
 *
 * PHP 7.0以上、mbstring必須。
 * 同期先: NicoFlick/Sources/Classes/SpoonClass.swift の getLevelStarReferencevalueV2()。
 * 難易度の係数・集計・丸めを変更する際は、Swift版も同時に更新すること。
 *
 * 【要点】
 * - 星1〜7は旧式を返し、星8以上を密度評価で細分化する。
 * - 通常の忙しさ50%、難所35%、繰り返し現れる2秒密集15%で基礎点を作る。
 * - タップ文字と反復入力は少し易しく扱う。
 * - 星8を起点に星14まで細かな直線、それ以降は平方根曲線で評価する。
 *
 * 【詳細】
 * 1. FULLがfalseなら、旧式と同じ条件でゲーム対象ノーツだけを抽出する。
 * 2. 入力の重みは通常フリック1.0、中央タップ0.82、同字連続はさらに0.78倍、
 *    2〜4文字周期の反復はさらに0.90倍とする。
 * 3. 隣接ノーツ間隔を1秒あたりの重み付き入力数へ変換する。
 *    80ms未満は80msとして上限を設け、3秒以上の間隔は休符として除外する。
 * 4. 間隔密度の75パーセンタイル（持続的な忙しさ）と90パーセンタイル
 *    （上位10%の難所）を求める。
 * 5. 曲全体を500ms刻みで走査し、直前2秒間の密度の90パーセンタイルを求める。
 *    最大値ではないため、一度だけの密集より繰り返す密集を高く評価する。
 * 6. difficulty = P75×0.50 + P90×0.35 + 2秒窓P90×0.15。
 *    丸め前8までは1 + difficulty×1.75、その先は傾き3.5で星14まで評価する。
 *    星14超は固定係数0.58の平方根曲線で圧縮し、下限8の実数を返す。
 *    整数化と上限20への制限は呼び出し側で行う。
 *
 * @param string $notesString Spoons.export(mode: .NicoFlickDB) の出力
 * @param bool   $full        FULL譜面として全タイムタグを評価する場合はtrue
 * @return float 参考難易度（星1〜7は旧式の整数値を実数化、V2は下限8・上限なし）
 */
function getLevelStarReferenceValueFromText($notesString, $full = false): float
{
    $notesString = str_replace("\r\n", "\n", (string) $notesString);
    $full = (bool) $full;

    // ==================== 共通前処理：ノーツ文字列の解析 START ====================
    $offsetWhenPosted = 0;
    if (preg_match_all('/^@(.*?)\s*=\s*(.*?)$/m', $notesString, $tagMatches, PREG_SET_ORDER)) {
        foreach ($tagMatches as $tagMatch) {
            if ($tagMatch[1] === 'OffsetWhenPosted') {
                $offsetWhenPosted = (int) $tagMatch[2];
            }
        }
    }
    $notesString = preg_replace('/^@(.*?)\s*=\s*(.*?)$/m', '', $notesString);

    $normalizeWord = function ($word) {
        // Swiftの applyingTransform(.hiraganaToKatakana, reverse: true) と同じ方向。
        return mb_convert_kana($word, 'c', 'UTF-8');
    };

    $isCheckableWord = function ($word) use ($normalizeWord) {
        $normalized = $normalizeWord($word);
        if (in_array($normalized, array('ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ', 'っ', 'ゃ', 'ゅ', 'ょ', 'ー'), true)) {
            return false;
        }

        // Swift側は空文字もtrueになるため、*で同じ挙動にする。
        return preg_match('/\A[\x{3041}-\x{3096}]*\z/u', $word) === 1
            || preg_match('/\A(?:[\x{30A1}-\x{30F6}]|\x{30FC})*\z/u', $word) === 1;
    };

    $parseTimetagMilliseconds = function ($timetag) use ($offsetWhenPosted) {
        if (!preg_match('/\[(\d\d):(\d\d)[:.](\d\d)\]/', $timetag, $matches)) {
            return -1 - $offsetWhenPosted;
        }
        $milliseconds = ((int) $matches[1] * 60 * 1000)
            + ((int) $matches[2] * 1000)
            + ((int) $matches[3] * 10);
        return $milliseconds - $offsetWhenPosted;
    };

    // Spoons.init(timetagText:) と同じく、タイムタグまたはUnicode 1文字に分割する。
    preg_match_all('/\[[\d*][\d*]:[\d*][\d*][:.][\d*][\d*]\]|./us', $notesString, $tokenMatches);
    $tokens = isset($tokenMatches[0]) ? $tokenMatches[0] : array();
    $spoons = array();
    $pendingTimetag = '';

    foreach ($tokens as $token) {
        $isTimetag = preg_match('/\A\[[\d*][\d*]:[\d*][\d*][:.][\d*][\d*]\]\z/u', $token) === 1;
        if ($isTimetag) {
            // タイムタグが連続した場合、Swift側と同じく空文字ノーツを作る。
            if ($pendingTimetag !== '') {
                $spoons[] = array(
                    'word' => '',
                    'miriSec' => $parseTimetagMilliseconds($pendingTimetag),
                    'note' => strpos($pendingTimetag, '.') !== false,
                    'checkable' => $isCheckableWord(''),
                );
            }
            $pendingTimetag = $token;
            continue;
        }

        if ($pendingTimetag === '') {
            $spoons[] = array(
                'word' => $token,
                'miriSec' => -1,
                'note' => false,
                'checkable' => $isCheckableWord($token),
            );
        } else {
            $spoons[] = array(
                'word' => $token,
                'miriSec' => $parseTimetagMilliseconds($pendingTimetag),
                'note' => strpos($pendingTimetag, '.') !== false,
                'checkable' => $isCheckableWord($token),
            );
            $pendingTimetag = '';
        }
    }

    // ==================== 共通前処理：ノーツ文字列の解析 END ======================

    // ==================== 旧式：平均ノーツ間隔による計算 START ====================
    // 星1〜7なら、この結果をそのまま採用する。
    $previousMilliseconds = 0;
    $intervalCount = 0;
    $intervalSum = 0;
    foreach ($spoons as $spoon) {
        if ($spoon['miriSec'] === -1) {
            continue;
        }
        if ($spoon['checkable'] && !$spoon['note'] && !$full) {
            continue;
        }
        if ($previousMilliseconds === 0) {
            $previousMilliseconds = $spoon['miriSec'];
            continue;
        }

        $interval = $spoon['miriSec'] - $previousMilliseconds;
        $previousMilliseconds = $spoon['miriSec'];
        // 時系列を逆行する不正なタイムタグと、3秒以上の休符は平均から除外する。
        if ($interval < 0 || $interval >= 3000) {
            continue;
        }
        $intervalSum += $interval;
        $intervalCount++;
    }

    if ($intervalCount === 0) {
        $currentStar = 1;
    } else {
        $averageInterval = (float) intdiv($intervalSum, $intervalCount);
        $currentStar = (int) round(
            15.0 - sqrt(($averageInterval + 50.0) / 10.0)
        );
        $currentStar = min(10, max(1, $currentStar));
    }
    // 平均ノーツ間隔 / 星1: 1910ms, 星2: 1640ms, 星3: 1390ms, 星4: 1160ms, 星5: 950ms, 星6: 760ms, 星7: 590ms
    // ==================== 旧式：平均ノーツ間隔による計算 END ======================

    if ($currentStar <= 7) {
        return (float) $currentStar;
    }

    // ==================== 新式：入力内容と密度による計算 START ====================
    // 星8以上を評価する。
    $tapWeight = 0.82;
    $sameCharacterWeight = 0.78;
    $repeatedPhraseWeight = 0.90;
    $minimumInterval = 80;
    $ignoredInterval = 3000;
    $burstWindow = 2000;
    $burstSampleInterval = 500;

    $targetSpoons = array();
    $latestTargetTime = -1;
    foreach ($spoons as $spoon) {
        if ($spoon['miriSec'] < 0) {
            continue;
        }
        if ($full || !$spoon['checkable'] || $spoon['note']) {
            // 2秒窓は時刻昇順が前提。末尾の[00:00.00]など、逆行する異常値を除外する。
            if ($spoon['miriSec'] < $latestTargetTime) {
                continue;
            }
            $latestTargetTime = $spoon['miriSec'];
            $targetSpoons[] = $spoon;
        }
    }
    if (count($targetSpoons) < 2) {
        return 1.0;
    }

    $tapCharacters = 'あかさたなはまやらわがざだばぱアカサタナハマヤラワガザダバパ';
    $inputWeight = function ($index) use (
        $targetSpoons,
        $normalizeWord,
        $tapCharacters,
        $tapWeight,
        $sameCharacterWeight,
        $repeatedPhraseWeight
    ) {
        $word = $normalizeWord($targetSpoons[$index]['word']);
        $isTap = $word === '' || mb_strpos($tapCharacters, $word, 0, 'UTF-8') !== false;
        $weight = $isTap ? $tapWeight : 1.0;

        if ($index > 0 && $word === $normalizeWord($targetSpoons[$index - 1]['word'])) {
            $weight *= $sameCharacterWeight;
        } else {
            for ($distance = 2; $distance <= 4; $distance++) {
                if ($index >= $distance
                    && $word === $normalizeWord($targetSpoons[$index - $distance]['word'])) {
                    $weight *= $repeatedPhraseWeight;
                    break;
                }
            }
        }
        return $weight;
    };

    $strains = array();
    $timedWeights = array();
    $targetCount = count($targetSpoons);
    for ($index = 0; $index < $targetCount; $index++) {
        $weight = $inputWeight($index);
        $timedWeights[] = array(
            'time' => $targetSpoons[$index]['miriSec'],
            'weight' => $weight,
        );
        if ($index === 0) {
            continue;
        }

        $interval = $targetSpoons[$index]['miriSec'] - $targetSpoons[$index - 1]['miriSec'];
        if ($interval < 0 || $interval >= $ignoredInterval) {
            continue;
        }
        $transitionWeight = ($inputWeight($index - 1) + $weight) / 2.0;
        $actionsPerSecond = 1000.0 / max($interval, $minimumInterval);
        $strains[] = $actionsPerSecond * $transitionWeight;
    }
    if (count($strains) === 0) {
        return 1.0;
    }

    sort($strains, SORT_NUMERIC);
    $percentile = function ($sortedValues, $value) {
        $position = (int) round((count($sortedValues) - 1) * $value);
        return $sortedValues[$position];
    };

    $burstRates = array();
    $burstStart = 0;
    $burstEnd = 0;
    $burstWeight = 0.0;
    $sampleTime = $timedWeights[0]['time'];
    $lastTime = $timedWeights[count($timedWeights) - 1]['time'];
    $timedWeightCount = count($timedWeights);

    while ($sampleTime <= $lastTime) {
        while ($burstEnd < $timedWeightCount && $timedWeights[$burstEnd]['time'] <= $sampleTime) {
            $burstWeight += $timedWeights[$burstEnd]['weight'];
            $burstEnd++;
        }
        while ($burstStart < $burstEnd
            && $timedWeights[$burstStart]['time'] < $sampleTime - $burstWindow) {
            $burstWeight -= $timedWeights[$burstStart]['weight'];
            $burstStart++;
        }
        $burstRates[] = $burstWeight * 1000.0 / $burstWindow;
        $sampleTime += $burstSampleInterval;
    }

    if (($lastTime - $timedWeights[0]['time']) % $burstSampleInterval !== 0) {
        while ($burstEnd < $timedWeightCount) {
            $burstWeight += $timedWeights[$burstEnd]['weight'];
            $burstEnd++;
        }
        while ($burstStart < $burstEnd
            && $timedWeights[$burstStart]['time'] < $lastTime - $burstWindow) {
            $burstWeight -= $timedWeights[$burstStart]['weight'];
            $burstStart++;
        }
        $burstRates[] = $burstWeight * 1000.0 / $burstWindow;
    }

    sort($burstRates, SORT_NUMERIC);
    $difficulty = $percentile($strains, 0.75) * 0.50
        + $percentile($strains, 0.90) * 0.35
        + $percentile($burstRates, 0.90) * 0.15;

    // Lv8（基礎点4）から等しい刻みで評価。Swift版と同じ係数・演算順を保つ。
    $preservedBoundaryStar = 8.0;
    $preservedBoundaryDifficulty = ($preservedBoundaryStar - 1.0) / 1.75;
    $middleSlope = 3.5;
    $linearStar = $difficulty < $preservedBoundaryDifficulty
        ? 1.0 + $difficulty * 1.75
        : $preservedBoundaryStar + ($difficulty - $preservedBoundaryDifficulty) * $middleSlope;

    // 調整目安: 基礎点4 → 8、約4.286 → 9、5.714 → 14、12.329 → 20.10（丸め前）。
    $curveStartStar = 14.0;
    $highDifficultyCurve = 0.58;
    $excess = max(0.0, $linearStar - $curveStartStar);
    $curvedStar = $linearStar <= $curveStartStar
        ? $linearStar
        : $curveStartStar + $excess / sqrt(1.0 + $highDifficultyCurve * $excess);

    // ==================== 新式：入力内容と密度による計算 END ======================
    return max(8.0, $curvedStar);
}
