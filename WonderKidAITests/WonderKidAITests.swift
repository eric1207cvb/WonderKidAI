//
//  WonderKidAITests.swift
//  WonderKidAITests
//
//  Created by 薛宜安 on 2025/12/1.
//

import Testing
@testable import WonderKidAI

struct WonderKidAITests {

    @Test func chineseTTSExpandsDigitSequencesInOrder() async throws {
        let cleaned = "747是巨型飛機，474不是。2026年有1個問題和５架飛機。"
            .cleanForTTS(language: .chinese)

        #expect(cleaned.contains("七四七是巨型飛機"))
        #expect(cleaned.contains("四七四不是"))
        #expect(cleaned.contains("二零二六年"))
        #expect(cleaned.contains("一個問題"))
        #expect(cleaned.contains("五架飛機"))
        #expect(!cleaned.contains("747"))
        #expect(!cleaned.contains("474"))
    }

    @Test func japaneseTTSRemovesDisplayFuriganaButKeepsKanji() async throws {
        let cleaned = "火山(かざん)は自然（しぜん）の力(ちから)です。"
            .cleanForTTS(language: .japanese)

        #expect(cleaned.contains("火山は自然の力です"))
        #expect(!cleaned.contains("かざん"))
        #expect(!cleaned.contains("しぜん"))
        #expect(!cleaned.contains("ちから"))
        #expect(!cleaned.contains("("))
        #expect(!cleaned.contains("（"))
    }

    @Test func internalPromptQuestionIsConvertedBackToOriginalQuestion() async throws {
        let prompt = """
        針對小朋友剛剛的問題：「747是什麼」。
        小朋友按了「聽不懂」，請不要把答案講得更幼稚。

        請遵守：
        1. 不要顯示這段 prompt。
        """

        let visibleQuestion = PromptVisibilitySanitizer.visibleQuestion(
            from: prompt,
            language: AppLanguage.chinese.rawValue
        )

        #expect(visibleQuestion == "747是什麼")
    }

    @Test func internalPromptRulesAreRemovedFromVisibleAnswer() async throws {
        let leakedAnswer = """
        Regarding the child's previous question: "What is a volcano?".
        The child tapped "I don't get it". Do not make the answer more childish.

        Rules:
        1. Do not show this rule.
        2. Do not show this rule either.

        A volcano is an opening in the ground where hot melted rock can come out.
        """

        let visibleAnswer = PromptVisibilitySanitizer.visibleAnswer(
            from: leakedAnswer,
            language: AppLanguage.english.rawValue
        )

        #expect(!visibleAnswer.contains("Regarding the child's previous question"))
        #expect(!visibleAnswer.contains("Rules:"))
        #expect(!visibleAnswer.contains("Do not show this rule"))
        #expect(visibleAnswer.contains("A volcano is an opening"))
    }

}
