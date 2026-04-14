require 'fastlane/plugin/upload_galaxystore'

describe Fastlane::Helper::LanguageMapper do
  describe '.map_bcp47' do
    context 'simple one-to-one mappings' do
      it 'maps English' do
        expect(described_class.map_bcp47('en')).to eq('ENG')
      end

      it 'maps regional English variants by stripping the region' do
        expect(described_class.map_bcp47('en-US')).to eq('ENG')
        expect(described_class.map_bcp47('en-GB')).to eq('ENG')
        expect(described_class.map_bcp47('en-AU')).to eq('ENG')
      end

      it 'maps French' do
        expect(described_class.map_bcp47('fr')).to eq('FRA')
        expect(described_class.map_bcp47('fr-FR')).to eq('FRA')
        expect(described_class.map_bcp47('fr-CA')).to eq('FRA')
      end

      it 'maps German' do
        expect(described_class.map_bcp47('de')).to eq('DEU')
        expect(described_class.map_bcp47('de-AT')).to eq('DEU')
      end

      it 'maps Spanish variants' do
        expect(described_class.map_bcp47('es')).to eq('SPA')
        expect(described_class.map_bcp47('es-ES')).to eq('SPA')
        expect(described_class.map_bcp47('es-419')).to eq('SPA')
        expect(described_class.map_bcp47('es-US')).to eq('SPA')
      end

      it 'maps Portuguese variants' do
        expect(described_class.map_bcp47('pt')).to eq('POR')
        expect(described_class.map_bcp47('pt-BR')).to eq('POR')
        expect(described_class.map_bcp47('pt-PT')).to eq('POR')
      end

      it 'maps Korean' do
        expect(described_class.map_bcp47('ko')).to eq('KOR')
      end

      it 'maps Japanese' do
        expect(described_class.map_bcp47('ja')).to eq('JPN')
      end

      it 'maps Arabic' do
        expect(described_class.map_bcp47('ar')).to eq('ARA')
      end
    end

    context 'Norwegian variants' do
      it 'maps Bokmål, generic Norwegian, and Nynorsk all to NOR' do
        expect(described_class.map_bcp47('nb')).to eq('NOR')
        expect(described_class.map_bcp47('no')).to eq('NOR')
        expect(described_class.map_bcp47('nn')).to eq('NOR')
      end
    end

    context 'Chinese variants' do
      it 'maps Simplified Chinese variants to ZHO' do
        expect(described_class.map_bcp47('zh-CN')).to eq('ZHO')
        expect(described_class.map_bcp47('zh-Hans')).to eq('ZHO')
        expect(described_class.map_bcp47('zh-SG')).to eq('ZHO')
      end

      it 'maps Traditional Chinese variants to 002' do
        expect(described_class.map_bcp47('zh-TW')).to eq('002')
        expect(described_class.map_bcp47('zh-Hant')).to eq('002')
        expect(described_class.map_bcp47('zh-HK')).to eq('002')
      end

      it 'returns nil for unknown Chinese variants' do
        expect(described_class.map_bcp47('zh-XX')).to be_nil
      end
    end

    context 'legacy language codes' do
      it 'maps legacy Hebrew code iw to HEB' do
        expect(described_class.map_bcp47('iw')).to eq('HEB')
        expect(described_class.map_bcp47('he')).to eq('HEB')
      end

      it 'maps legacy Indonesian code in to IND' do
        expect(described_class.map_bcp47('in')).to eq('IND')
        expect(described_class.map_bcp47('id')).to eq('IND')
      end
    end

    context 'unmapped languages' do
      it 'returns nil for languages with no Galaxy Store equivalent' do
        expect(described_class.map_bcp47('af')).to be_nil   # Afrikaans
        expect(described_class.map_bcp47('fil')).to be_nil  # Filipino
        expect(described_class.map_bcp47('sw')).to be_nil   # Swahili
        expect(described_class.map_bcp47('ms')).to be_nil   # Malay
      end

      it 'returns nil for nil input' do
        expect(described_class.map_bcp47(nil)).to be_nil
      end
    end
  end

  describe '.resolve_languages' do
    context 'simple mappings with no collisions' do
      it 'maps a list of unique languages correctly' do
        result = described_class.resolve_languages(%w[en fr de ko])
        expect(result).to eq({
          'ENG' => 'en',
          'FRA' => 'fr',
          'DEU' => 'de',
          'KOR' => 'ko'
        })
      end

      it 'skips unmapped languages with a warning' do
        expect(Fastlane::UI).to receive(:important).with(/No Galaxy Store language mapping found for 'fil'/)
        result = described_class.resolve_languages(%w[en fil])
        expect(result.keys).to contain_exactly('ENG')
      end
    end

    context 'many-to-one collision resolution' do
      it 'prefers the neutral variant over regional ones for English' do
        expect(Fastlane::UI).to receive(:important).with(/Multiple variants found for ENG/)
        result = described_class.resolve_languages(%w[en en-US en-GB])
        expect(result['ENG']).to eq('en')
      end

      it 'prefers es over es-419 for Spanish' do
        expect(Fastlane::UI).to receive(:important).with(/Multiple variants found for SPA/)
        result = described_class.resolve_languages(%w[es es-419 es-ES])
        expect(result['SPA']).to eq('es')
      end

      it 'prefers es-ES over es-419 when no neutral es is present' do
        expect(Fastlane::UI).to receive(:important).with(/Multiple variants found for SPA/)
        result = described_class.resolve_languages(%w[es-ES es-419])
        expect(result['SPA']).to eq('es-ES')
      end

      it 'prefers nb over nn for Norwegian' do
        expect(Fastlane::UI).to receive(:important).with(/Multiple variants found for NOR/)
        result = described_class.resolve_languages(%w[nb nn])
        expect(result['NOR']).to eq('nb')
      end
    end

    context 'developer priority overrides' do
      it 'uses the override when the specified variant is available' do
        expect(Fastlane::UI).to receive(:important).with(/Multiple variants found for SPA/)
        result = described_class.resolve_languages(%w[es es-419 es-ES], 'SPA' => 'es-419')
        expect(result['SPA']).to eq('es-419')
      end

      it 'falls back to default priority when the override variant is not available' do
        expect(Fastlane::UI).to receive(:important).with(/Multiple variants found for SPA/)
        expect(Fastlane::UI).to receive(:important).with(/language_priority override 'es-MX' for SPA not found/)
        result = described_class.resolve_languages(%w[es es-419], 'SPA' => 'es-MX')
        expect(result['SPA']).to eq('es')
      end

      it 'uses pt-BR over pt when override is set' do
        expect(Fastlane::UI).to receive(:important).with(/Multiple variants found for POR/)
        result = described_class.resolve_languages(%w[pt pt-BR pt-PT], 'POR' => 'pt-BR')
        expect(result['POR']).to eq('pt-BR')
      end
    end

    context 'edge cases' do
      it 'handles a single language without warnings' do
        expect(Fastlane::UI).not_to receive(:important)
        result = described_class.resolve_languages(%w[en])
        expect(result).to eq({ 'ENG' => 'en' })
      end

      it 'returns an empty hash for an empty input' do
        result = described_class.resolve_languages([])
        expect(result).to eq({})
      end

      it 'handles both Simplified and Traditional Chinese independently' do
        result = described_class.resolve_languages(%w[zh-CN zh-TW])
        expect(result['ZHO']).to eq('zh-CN')
        expect(result['002']).to eq('zh-TW')
      end
    end
  end
end
